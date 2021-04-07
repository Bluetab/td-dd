defmodule TdDq.Rules.RuleResults do
  @moduledoc """
  The Rule Results context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDq.Cache.RuleLoader
  alias TdDq.Executions.Execution
  alias TdDq.Repo
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  require Logger

  @index_worker Application.compile_env(:td_dq, :index_worker)

  def get_rule_result(id) do
    Repo.get_by(RuleResult, id: id)
  end

  def list_rule_results do
    RuleResult
    |> join(:inner, [rr, ri], ri in Implementation,
      on: rr.implementation_key == ri.implementation_key
    )
    |> join(:inner, [_, ri, r], r in Rule, on: r.id == ri.rule_id)
    |> where([_, _, r], is_nil(r.deleted_at))
    |> where([_, ri, _], is_nil(ri.deleted_at))
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
  def create_rule_result(params \\ %{}) do
    changeset = RuleResult.changeset(params)

    Multi.new()
    |> Multi.insert(:result, changeset)
    |> Multi.run(:executions, fn _repo, %{result: result} ->
      res = update_executions(result)
      {:ok, res}
    end)
    |> Repo.transaction()
    |> on_create()
  end

  defp update_executions(%{id: id, implementation_key: key, inserted_at: ts} = _result) do
    Execution
    |> select([e], e)
    |> where([e], is_nil(e.result_id))
    |> join(:inner, [e], i in assoc(e, :implementation))
    |> where([e, i], i.implementation_key == ^key)
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

  @doc """
  Returns last rule_result for each active implementation of rule
  """
  def get_latest_rule_results(%Rule{} = rule) do
    rule
    |> Repo.preload(:rule_implementations)
    |> Map.get(:rule_implementations)
    |> Enum.filter(&is_nil(Map.get(&1, :deleted_at)))
    |> Enum.map(&get_latest_rule_result(&1.implementation_key))
    |> Enum.filter(& &1)
  end

  def get_latest_rule_result(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
    |> join(:inner, [r, ri], ri in Implementation,
      on: r.implementation_key == ri.implementation_key
    )
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  def get_implementation_results(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
    |> order_by(desc: :date)
    |> Repo.all()
  end

  def delete_rule_result(%RuleResult{} = rule_result, rule) do
    rule_result
    |> Repo.delete()
    |> refresh_on_delete(rule)

    # TODO: Audit event?
  end

  defp refresh_on_delete({:ok, _} = res, %{id: rule_id}) do
    RuleLoader.refresh(rule_id)
    res
  end

  defp refresh_on_delete(res, _), do: res

  def bulk_load(records) do
    Logger.info("Loading rule results...")

    Timer.time(
      fn -> do_bulk_load(records) end,
      fn millis, _ -> Logger.info("Rule results loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(records) do
    Multi.new()
    |> Multi.run(:ids, fn _, _ -> bulk_insert(records) end)
    |> Multi.run(:results, &select_results/2)
    |> Multi.run(:audit, Audit, :rule_results_created, [0])
    |> Repo.transaction()
    |> bulk_refresh()
  end

  defp bulk_refresh(res) do
    with {:ok, %{results: results}} <- res,
         rule_ids <- rule_ids_from_results(results) do
      RuleLoader.refresh(rule_ids)
      res
    end
  end

  defp rule_ids_from_results(results) do
    results
    |> Enum.map(&Map.get(&1, :rule_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp bulk_insert(records) do
    records
    |> Enum.with_index(2)
    |> Enum.map(fn {params, row_number} -> Map.put(params, "row_number", row_number) end)
    |> Enum.map(&RuleResult.changeset/1)
    |> Enum.reduce_while([], &reduce_changesets/2)
    |> case do
      ids when is_list(ids) -> {:ok, ids}
      error -> error
    end
  end

  defp reduce_changesets(%{} = changeset, acc) do
    case Repo.insert(changeset) do
      {:ok, %{id: id}} -> {:cont, [id | acc]}
      error -> {:halt, error}
    end
  end

  defp select_results(_repo, %{ids: ids}) do
    results =
      RuleResult
      |> join(:inner, [r], i in Implementation, on: r.implementation_key == i.implementation_key)
      |> join(:inner, [res, i], rule in assoc(i, :rule))
      |> select([res], %{})
      |> select_merge(
        [res, _, _],
        map(res, ^~w(id implementation_key date result errors records params inserted_at)a)
      )
      |> select_merge([_, i, _], %{implementation_id: i.id, rule_id: i.rule_id})
      |> select_merge(
        [_, _, rule],
        map(rule, ^~w(business_concept_id goal name minimum result_type)a)
      )
      |> where([res], res.id in ^ids)
      |> order_by([res], res.id)
      |> Repo.all()
      |> Enum.map(&Map.put(&1, :status, status(&1)))

    {:ok, results}
  end

  defp status(%{result_type: "errors_number", errors: errors, minimum: threshold, goal: target}) do
    cond do
      Decimal.compare(errors, threshold) == :gt -> "fail"
      Decimal.compare(errors, target) == :gt -> "warn"
      true -> "success"
    end
  end

  defp status(%{result_type: "percentage", result: result, minimum: threshold, goal: target}) do
    cond do
      Decimal.compare(result, threshold) == :lt -> "fail"
      Decimal.compare(result, target) == :lt -> "warn"
      true -> "success"
    end
  end
end
