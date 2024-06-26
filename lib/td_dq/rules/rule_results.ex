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
  alias TdDq.Implementations.Search.Indexer, as: ImplementationsIndexer
  alias TdDq.Rules.Audit
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.Search.Indexer, as: RulesIndexer

  require Logger

  @pagination_params [:limit, :before, :after]

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def get_rule_result(id, options \\ []) do
    Repo.get_by(RuleResult, id: id)
    |> Repo.preload(options[:preload] || [])
  end

  def add_offset(%{before: id} = params) when is_binary(id), do: add_offset(params, id)
  def add_offset(%{after: id} = params) when is_binary(id), do: add_offset(params, id)
  def add_offset(params), do: Map.put(params, :offset, 0)

  def add_offset(%{implementation_ref: implementation_ref} = params, rule_result_id) do
    case get_offset(implementation_ref, rule_result_id) do
      nil -> Map.put(params, :offset, 0)
      offset -> Map.put(params, :offset, offset)
    end
  end

  defp get_offset(implementation_ref, rule_result_id) do
    RuleResult
    |> join(:inner, [rr], ri in Implementation, on: ri.id == rr.implementation_id)
    |> where([_rr, ri], ri.implementation_ref == ^implementation_ref)
    |> order_by([rr, ri], desc: ri.version, desc: rr.date, desc: rr.id)
    |> select([rr, ri], %{
      id: rr.id,
      version: ri.version,
      row: row_number() |> over(order_by: [desc: ri.version, desc: rr.date, desc: rr.id])
    })
    |> subquery()
    |> where([rr], rr.id == ^rule_result_id)
    |> select([rr], rr.row - 1)
    |> limit(1)
    |> Repo.one()
  end

  def list_rule_results(params \\ %{}) do
    params
    |> add_offset()
    |> rule_results_query()
    |> select([rr, _ri], rr)
    |> Repo.all()
  end

  def list_rule_results_paginate(params \\ %{}) do
    RuleResult
    |> join(:inner, [rr, ri], ri in Implementation, on: rr.implementation_id == ri.id)
    |> where([_, ri, _], is_nil(ri.deleted_at))
    |> add_filters(params)
    |> order(params)
    |> paginate_all(params)
  end

  def list_segment_results(params \\ %{}) do
    RuleResult
    |> where([rr], not is_nil(rr.parent_id))
    |> add_filters(params)
    |> order(params)
    |> paginate_all(params)
  end

  def list_segment_results_by_parent_id(parent_id, _params \\ %{}) do
    RuleResult
    |> where([rr], rr.parent_id == ^parent_id)
    |> Repo.all()
  end

  def has_segments(parent_ids) when is_list(parent_ids) do
    RuleResult
    |> where([rr], rr.parent_id in ^parent_ids)
    |> select([rr], rr.parent_id)
    |> group_by([rr], rr.parent_id)
    |> Repo.all()
  end

  def get_by(%Implementation{id: implementation_id} = _implementation) do
    RuleResult
    |> where([rr], rr.implementation_id == ^implementation_id)
    |> where([rr], is_nil(rr.parent_id))
    |> order_by([rr], desc: rr.date)
    |> Repo.all()
  end

  def has_segments?(%RuleResult{id: implementation_id}) do
    RuleResult
    |> where([rr], rr.parent_id == ^implementation_id)
    |> limit(1)
    |> Repo.one() != nil
  end

  def has_remediation?(%RuleResult{id: implementation_id}) do
    RuleResult
    |> where([rr], rr.id == ^implementation_id)
    |> join(:inner, [rr], rm in assoc(rr, :remediation))
    |> limit(1)
    |> Repo.one() != nil
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

    execution_id = Map.get(params, "execution_id", nil)

    Multi.new()
    |> Multi.insert(:result, changeset)
    |> Multi.run(:segments, fn _, %{result: result} ->
      bulk_segments(result, params)
    end)
    |> Multi.run(:executions, fn _repo, %{result: result} ->
      res = update_executions(result, execution_id)
      {:ok, res}
    end)
    |> Multi.run(:events, fn _, %{executions: {_, executions}} ->
      {_, events} = QualityEvents.complete(executions)
      {:ok, events}
    end)
    |> Multi.run(:results, fn _, %{result: %{id: id}} ->
      select_results([id])
    end)
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
         %{id: id, implementation_id: implementation_id, inserted_at: ts} = _result,
         execution_id
       ) do
    Execution
    |> select([e], e)
    |> where([e], is_nil(e.result_id))
    |> maybe_where_execution_id(execution_id)
    |> join(:inner, [e], i in assoc(e, :implementation))
    |> where([e, i], i.id == ^implementation_id)
    |> update(set: [result_id: ^id, updated_at: ^ts])
    |> Repo.update_all([])
  end

  defp maybe_where_execution_id(query, nil), do: query

  defp maybe_where_execution_id(query, execution_id) do
    query |> where([e], e.id == ^execution_id)
  end

  defp on_create({:ok, %{result: rule_result}} = result) do
    case Repo.preload(rule_result, [:implementation, :rule]) do
      %{
        rule: %{id: rule_id},
        implementation: %{id: implementation_id}
      } ->
        RulesIndexer.reindex([rule_id])
        ImplementationsIndexer.reindex([implementation_id])

      %{implementation: %{id: implementation_id}} ->
        ImplementationsIndexer.reindex([implementation_id])
    end

    result
  end

  defp on_create(result), do: result

  @spec get_latest_rule_result(Implementation.t()) :: RuleResult.t() | nil
  def get_latest_rule_result(%Implementation{implementation_ref: implementation_ref}) do
    implementation_ids =
      Implementation
      |> where(implementation_ref: ^implementation_ref)
      |> select([i], i.id)

    RuleResult
    |> where([rr], rr.implementation_id in subquery(implementation_ids))
    |> limit(1)
    |> order_by([rr], desc: rr.date)
    |> Repo.one()
    |> get_rule_result_thresholds()
  end

  def get_rule_result_thresholds(nil), do: nil

  def get_rule_result_thresholds(%{implementation_id: implementation_id} = ruleResult) do
    %{minimum: minimum, goal: goal} = TdDd.Repo.get(Implementation, implementation_id)

    ruleResult
    |> Map.put(:minimum, minimum)
    |> Map.put(:goal, goal)
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
      |> join(:left, [res, i], rule in assoc(i, :rule))
      |> select([res], %{})
      |> select_merge(
        [res, _, _],
        map(res, ^~w(id implementation_id date result errors records params inserted_at)a)
      )
      |> select_merge([_, i, _], %{
        implementation_id: i.id,
        implementation_ref: i.implementation_ref,
        implementation_key: i.implementation_key,
        rule_id: i.rule_id,
        goal: i.goal,
        minimum: i.minimum,
        result_type: i.result_type,
        # Will be overwritten by rule domain_id below
        domain_id: i.domain_id
        # if implementation has an associated rule
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

  defp status(%{
         result_type: "percentage",
         records: records,
         result: result,
         minimum: threshold,
         goal: target
       }) do
    cond do
      records === 0 -> "empty_dataset"
      Decimal.compare(result, Decimal.from_float(threshold)) == :lt -> "fail"
      Decimal.compare(result, Decimal.from_float(target)) == :lt -> "warn"
      true -> "success"
    end
  end

  defp status(%{
         result_type: "deviation",
         records: records,
         result: result,
         minimum: threshold,
         goal: target
       }) do
    cond do
      records === 0 -> "empty_dataset"
      Decimal.compare(result, Decimal.from_float(threshold)) == :gt -> "fail"
      Decimal.compare(result, Decimal.from_float(target)) == :gt -> "warn"
      true -> "success"
    end
  end

  defp status(%{
         result_type: "errors_number",
         records: records,
         errors: errors,
         minimum: threshold,
         goal: target
       }) do
    cond do
      records === 0 -> "empty_dataset"
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

  defp add_filters(query, %{"since" => ts, "from" => "updated_at"}) do
    query
    |> where([rr, _, _], rr.updated_at >= ^ts)
  end

  defp add_filters(query, %{"since" => ts}) do
    query
    |> where([rr, _, _], rr.date >= ^ts)
  end

  defp add_filters(query, %{ref: ref}) do
    query
    |> where([_rr, ri, _], ri.implementation_ref == ^ref)
  end

  defp add_filters(query, _params), do: query

  defp where_cursor(query, %{cursor: %{offset: offset}}) when is_integer(offset) do
    offset(query, ^offset)
  end

  defp where_cursor(query, _), do: query

  defp page_limit(query, %{cursor: %{size: size}}) when is_integer(size) do
    limit(query, ^size)
  end

  defp page_limit(query, _), do: query

  defp order(query, %{"from" => "updated_at"}),
    do: order_by(query, [rr], asc: rr.updated_at, asc: rr.id)

  defp order(query, _params), do: order_by(query, [rr], asc: rr.date, asc: rr.id)

  defp get_cursor_params(%{"cursor" => %{} = cursor}) do
    offset = Map.get(cursor, "offset")
    size = Map.get(cursor, "size")

    %{cursor: %{offset: offset, size: size}}
  end

  defp get_cursor_params(params), do: params

  defp paginate_all(query, params) do
    cursor_params = get_cursor_params(params)

    cursor_query =
      query
      |> where_cursor(cursor_params)
      |> page_limit(cursor_params)

    total_query = select(subquery(query), [rr], count())

    Multi.new()
    |> Multi.all(:all, cursor_query)
    |> Multi.one(:total, total_query)
    |> Repo.transaction()
  end

  def rule_results_query(params) do
    Enum.reduce(params, RuleResult, fn
      {:implementation_ref, implementation_ref}, q ->
        q
        |> join(:inner, [rr], ri in assoc(rr, :implementation))
        |> where([_rr, ri], ri.implementation_ref == ^implementation_ref)

      {:limit, lim}, q ->
        limit(q, ^lim)

      {:order_by, [:desc, :imp_version, :result_date, :result_id]}, q ->
        order_by(q, [rr, ri], desc: ri.version, desc: rr.date, desc: rr.id)

      {:order_by, [:asc, :imp_version, :result_date, :result_id]}, q ->
        order_by(q, [rr, ri], asc: ri.version, asc: rr.date, asc: rr.id)

      {:preload, preloads}, q ->
        preload(q, ^preloads)

      {:after, _}, q ->
        temporal_offset = Map.get(params, :offset, 0)
        limit = Map.get(params, :limit, :infinity)
        offset_value = max(0, temporal_offset - limit)
        offset(q, ^offset_value)

      {:before, _}, q ->
        offset_value = Map.get(params, :offset, 0)
        offset(q, ^offset_value + 1)

      _, q ->
        q
    end)
  end

  def min_max_count(params) do
    params = Map.drop(params, @pagination_params)

    %{
      count: count_results(params),
      last_cursor: last_result(params),
      first_cursor: first_result(params)
    }
  end

  defp count_results(params) do
    params
    |> Map.drop([:order_by])
    |> rule_results_query
    |> select([rr, _ri], count(rr.id))
    |> Repo.one()
  end

  defp first_result(params) do
    params
    |> rule_results_query
    |> select([:id])
    |> limit(1)
    |> Repo.one()
  end

  defp last_result(params) do
    [:desc | order_by] = Map.get(params, :order_by)

    params
    |> Map.put(:order_by, [:asc, order_by])
    |> rule_results_query
    |> select([:id])
    |> limit(1)
    |> Repo.one()
  end

  ## Dataloader
  def datasource do
    timeout = Application.get_env(:td_dd, TdDd.Repo)[:timeout]
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: timeout)
  end

  defp query(queryable, params) do
    Enum.reduce(params, queryable, fn
      {:preload, preload}, q -> preload(q, ^preload)
    end)
  end
end
