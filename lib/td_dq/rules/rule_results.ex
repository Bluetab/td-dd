defmodule TdDq.Rules.RuleResults do
  @moduledoc """
  The Rule Results context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Cache.RuleLoader
  alias TdDq.Events.QualityEvents
  alias TdDq.Executions.Execution
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  require Logger

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  def get_rule_result(id, options \\ []) do
    Repo.get_by(RuleResult, id: id)
    |> Repo.preload(options[:preload] || [])
  end

  def list_rule_results(params \\ %{}) do
    RuleResult
    |> join(:inner, [rr, ri], ri in Implementation, on: rr.implementation_id == ri.id)
    |> join(:inner, [_, ri, r], r in Rule, on: r.id == ri.rule_id)
    |> where([_, _, r], is_nil(r.deleted_at))
    |> where([_, ri, _], is_nil(ri.deleted_at))
    |> get_results_gt_date(params)
    |> Repo.all()
  end

  def list_segment_results(_params \\ %{}) do
    RuleResult
    |> where([rr], not is_nil(rr.parent_id))
    |> Repo.all()
  end

  def list_segment_results_by_parent_id(parent_id, _params \\ %{}) do
    RuleResult
    |> where([rr], rr.parent_id == ^parent_id)
    |> Repo.all()
  end

  def has_segments(parent_ids) do
    RuleResult
    |> where([rr], rr.parent_id in ^parent_ids)
    |> select([rr], rr.parent_id)
    |> group_by([rr], rr.parent_id)
    |> Repo.all()
  end

  @doc """
  Creates a rule_result.

  ## Examples

      iex> create_rule_result(%{field: value})
      {:ok, %{result: RuleResult{}}}

      iex> create_rule_result(%{field: bad_value})
      {:error, failed_operation, failed_value, changes_so_far}

  """
  def create_rule_result(
        %Implementation{rule_id: rule_id, result_type: result_type} = impl,
        params \\ %{}
      ) do
    changeset =
      RuleResult.changeset(
        %RuleResult{result_type: result_type, rule_id: rule_id},
        impl,
        params
      )

    Multi.new()
    |> Multi.insert(:result, changeset)
    |> Multi.run(:segments, fn _, %{result: result} ->
      bulk_segments(result, params)
    end)
    |> Multi.run(:executions, fn _repo, %{result: result} ->
      res = update_executions(result)
      {:ok, res}
    end)
    |> Multi.run(:events, fn _, %{executions: {_, executions}} ->
      {_, events} = QualityEvents.complete(executions)
      {:ok, events}
    end)
    |> Multi.run(:results, fn _, %{result: %{id: id}} -> select_results([id]) end)
    |> Multi.run(:audit, Audit, :rule_results_created, [0])
    |> Multi.run(:implementation, fn _, _ -> {:ok, impl} end)
    |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
    |> Repo.transaction()
    |> on_create()
  end

  defp bulk_segments(result, %{"segments" => segments, "date" => date}) when is_list(segments) do
    segments
    |> Enum.map(&Map.put(&1, "date", date))
    |> Enum.map(&changeset(&1, result))
    |> Enum.reduce_while([], &reduce_changesets/2)
    |> case do
      ids when is_list(ids) -> {:ok, ids}
      error -> error
    end
  end

  defp bulk_segments(_result, _params), do: {:ok, []}

  defp changeset(%{} = segment, %{id: parent_id, result_type: result_type}) do
    RuleResult.changeset(
      %RuleResult{result_type: result_type, parent_id: parent_id},
      %{},
      segment
    )
  end

  defp reduce_changesets(%{} = changeset, acc) do
    case Repo.insert(changeset) do
      {:ok, %{id: id}} -> {:cont, [id | acc]}
      error -> {:halt, error}
    end
  end

  defp update_executions(
         %{id: id, implementation_id: implementation_id, inserted_at: ts} = _result
       ) do
    Execution
    |> select([e], e)
    |> where([e], is_nil(e.result_id))
    |> join(:inner, [e], i in assoc(e, :implementation))
    |> where([e, i], i.id == ^implementation_id)
    |> update(set: [result_id: ^id, updated_at: ^ts])
    |> Repo.update_all([])
  end

  defp on_create({:ok, %{result: rule_result}} = result) do
    %{
      rule: %{id: rule_id},
      implementation: %{id: implementation_id}
    } = Repo.preload(rule_result, [:implementation, :rule])

    @index_worker.reindex_rules(rule_id)
    @index_worker.reindex_implementations(implementation_id)

    result
  end

  defp on_create(result), do: result

  @spec get_latest_rule_result(Implementation.t()) :: RuleResult.t() | nil
  def get_latest_rule_result(%Implementation{id: id}) do
    RuleResult
    |> where([rr], rr.implementation_id == ^id)
    |> limit(1)
    |> order_by([rr], desc: rr.date)
    |> Repo.one()
  end

  def delete_rule_result(%RuleResult{} = rule_result) do
    %{rule: rule} = Repo.preload(rule_result, :rule)

    rule_result
    |> Repo.delete()
    |> refresh_on_delete(rule)

    # TODO: audit result deletion?
  end

  def select_results(ids) do
    results =
      RuleResult
      |> join(:inner, [r], i in Implementation, on: r.implementation_id == i.id)
      |> join(:inner, [res, i], rule in assoc(i, :rule))
      |> select([res], %{})
      |> select_merge(
        [res, _, _],
        map(res, ^~w(id implementation_id date result errors records params inserted_at)a)
      )
      |> select_merge([_, i, _], %{
        implementation_id: i.id,
        implementation_key: i.implementation_key,
        rule_id: i.rule_id,
        goal: i.goal,
        minimum: i.minimum,
        result_type: i.result_type
      })
      |> select_merge(
        [_, _, rule],
        map(rule, ^~w(domain_id business_concept_id name)a)
      )
      |> where([res], res.id in ^ids)
      |> order_by([res], res.id)
      |> Repo.all()
      |> Enum.map(&Map.put(&1, :status, status(&1)))

    {:ok, results}
  end

  defp status(%{result_type: "percentage", result: result, minimum: threshold, goal: target}) do
    cond do
      Decimal.compare(result, Decimal.from_float(threshold)) == :lt -> "fail"
      Decimal.compare(result, Decimal.from_float(target)) == :lt -> "warn"
      true -> "success"
    end
  end

  defp status(%{result_type: "deviation", result: result, minimum: threshold, goal: target}) do
    cond do
      Decimal.compare(result, Decimal.from_float(threshold)) == :gt -> "fail"
      Decimal.compare(result, Decimal.from_float(target)) == :gt -> "warn"
      true -> "success"
    end
  end

  defp status(%{result_type: "errors_number", errors: errors, minimum: threshold, goal: target}) do
    cond do
      Decimal.compare(errors, Decimal.from_float(threshold)) == :gt -> "fail"
      Decimal.compare(errors, Decimal.from_float(target)) == :gt -> "warn"
      true -> "success"
    end
  end

  defp refresh_on_delete({:ok, _} = res, %{id: rule_id}) do
    RuleLoader.refresh(rule_id)
    res
  end

  defp refresh_on_delete(res, _), do: res

  defp get_results_gt_date(query, %{"since" => ts}) do
    query
    |> where([rr, _, _], rr.date > ^ts)
  end

  defp get_results_gt_date(query, _params), do: query
end
