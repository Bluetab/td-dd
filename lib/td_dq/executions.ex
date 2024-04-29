defmodule TdDq.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Events.QualityEvent
  alias TdDq.Executions.Audit
  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group
  alias TdDq.Implementations.ImplementationQueries

  @pagination_params [:order_by, :limit, :before, :after]

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Fetches the `Execution` with the given id.
  """
  def get(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    Execution
    |> preload(^preloads)
    |> Repo.get(id)
  end

  @doc """
  Returns an execution group.
  """
  def get_group(%{"id" => id} = _params, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    Group
    |> preload(^preloads)
    |> Repo.get(id)
  end

  @doc """
  Returns a list of execution groups.
  """
  def list_groups(params \\ %{}) do
    params
    |> group_query()
    |> Repo.all()
  end

  def min_max_count(params) do
    params
    |> Map.drop(@pagination_params)
    |> executions_query()
    |> select([e], %{count: count(e), min_id: min(e.id), max_id: max(e.id)})
    |> Repo.one()
  end

  def group_min_max_count(params) do
    params
    |> Map.drop(@pagination_params)
    |> group_query()
    |> select([g], %{count: count(g), min_id: min(g.id), max_id: max(g.id)})
    |> Repo.one()
  end

  defp group_query(params) do
    Enum.reduce(params, Group, fn
      {:created_by_id, id}, q -> where(q, [g], g.created_by_id == ^id)
      {:order_by, order}, q -> order_by(q, ^order)
      {:limit, lim}, q -> limit(q, ^lim)
      {:before, id}, q -> where(q, [g], g.id < type(^id, :integer))
      {:after, id}, q -> where(q, [g], g.id > type(^id, :integer))
    end)
  end

  @doc """
  Returns a list of executions.
  """
  def list_executions(params \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    params
    |> executions_query()
    |> preload(^preloads)
    |> Repo.all()
  end

  def execution_filters(%{} = params) do
    q = executions_query(params)

    statuses =
      q
      |> subquery()
      |> join(:left, [e], qe in QualityEvent, on: qe.execution_id == e.id)
      |> order_by([_, qe], desc: qe.inserted_at, desc: qe.id)
      |> distinct([e], e.id)
      |> select([_, qe], %{status: fragment("coalesce(?, ?)", qe.type, "PENDING")})
      |> subquery()
      |> select([s], s.status)
      |> distinct(true)
      |> Repo.all()

    [%{field: "status", values: Enum.sort(statuses)}]
  end

  defp executions_query(%{} = params) do
    {pagination, params} = Map.split(params, @pagination_params)

    params
    |> cast()
    |> Map.merge(pagination)
    |> Enum.reduce(Execution, fn
      {:group_id, id}, q ->
        where(q, [e], e.group_id == ^id)

      {:execution_group_id, id}, q ->
        where(q, [e], e.group_id == ^id)

      {:status, "pending"}, q ->
        q
        |> join(:left, [e], r in assoc(e, :result), as: :result)
        |> join(:left, [e], qe in assoc(e, :quality_events), as: :event)
        |> where([result: r], is_nil(r.id))
        |> where([event: qe], is_nil(qe.execution_id))

      {:filters, filters}, q ->
        Enum.reduce(filters, q, fn
          {:status, statuses}, q ->
            sq = status_query()

            q
            |> join(:left, [e], s in subquery(sq), on: s.execution_id == e.id)
            |> where([_, s], fragment("coalesce(?, ?)", s.status, "PENDING") in ^statuses)
        end)

      {:sources, external_ids}, q ->
        sources_query = ImplementationQueries.implementation_sources_query(external_ids)
        join(q, :inner, [e], s in ^sources_query, on: e.implementation_id == s.implementation_id)

      {:ref, ref}, q ->
        ids_query = ImplementationQueries.implementation_ids_by_ref_query(ref)
        where(q, [e], e.implementation_id in subquery(ids_query))

      {:order_by, order}, q ->
        order_by(q, ^order)

      {:limit, lim}, q ->
        limit(q, ^lim)

      {:before, id}, q ->
        where(q, [e], e.id < type(^id, :integer))

      {:after, id}, q ->
        where(q, [e], e.id > type(^id, :integer))

      _, q ->
        q
    end)
  end

  defp cast(%{} = params) do
    types = %{
      group_id: :integer,
      execution_group_id: :integer,
      ref: :integer,
      filters: :map,
      source: :string,
      sources: {:array, :string},
      status: :string
    }

    {%{}, types}
    |> Changeset.cast(params, Map.keys(types))
    |> Changeset.update_change(:status, &String.downcase/1)
    |> merge_sources()
    |> Changeset.apply_changes()
  end

  defp merge_sources(%Changeset{} = cs) do
    case {Changeset.fetch_change(cs, :source), Changeset.fetch_change(cs, :sources)} do
      {:error, _} -> cs
      {{:ok, source}, :error} -> Changeset.put_change(cs, :sources, [source])
      {{:ok, source}, {:ok, _}} -> Changeset.update_change(cs, :sources, &[source | &1])
    end
    |> Changeset.delete_change(:source)
    |> Changeset.update_change(:sources, &Enum.uniq(Enum.sort(&1)))
  end

  @doc """
  Create an execution group.
  """
  def create_group(%{} = params) do
    params
    |> Group.changeset()
    |> do_create_group()
  end

  defp do_create_group(%Changeset{} = changeset) do
    Multi.new()
    |> Multi.insert(:group, changeset)
    |> Multi.update_all(
      :executions,
      fn %{group: %{id: group_id}} ->
        Execution
        |> where([e], e.group_id == ^group_id)
        |> join(:inner, [e], i in assoc(e, :implementation))
        |> update([e, i], set: [rule_id: fragment("?", i.rule_id)])
      end,
      []
    )
    |> Multi.run(:audit, Audit, :execution_group_created, [changeset])
    |> Repo.transaction()
  end

  ## Dataloader
  def datasource do
    timeout = Application.get_env(:td_dd, TdDd.Repo)[:timeout]
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: timeout)
  end

  defp query(QualityEvent, %{latest: true}), do: latest_event_query()
  defp query(queryable, _params), do: queryable

  def kv_datasource({:status_counts, %{}}, groups) do
    group_ids = Enum.map(groups, & &1.id)

    counts =
      Execution
      |> where([e], e.group_id in ^group_ids)
      |> join(:left, [e], qe in assoc(e, :quality_events))
      |> distinct([e], e.id)
      |> order_by([_, qe], desc: qe.inserted_at, desc: qe.id)
      |> select([e, qe], %{
        group_id: e.group_id,
        type: fragment("coalesce(?, 'PENDING')", qe.type),
        id: e.id
      })
      |> subquery()
      |> group_by([:group_id, :type])
      |> select([sq], %{id: sq.group_id, status: sq.type, count: count(sq)})
      |> Repo.all()
      |> Enum.group_by(& &1.id)

    Map.new(groups, fn %{id: id} = group -> {group, status_counts(counts, id)} end)
  end

  defp status_counts(counts, id) do
    counts
    |> Map.get(id, [])
    |> Map.new(fn %{status: status, count: count} -> {status, count} end)
  end

  defp latest_event_query do
    QualityEvent
    |> distinct([e], e.execution_id)
    |> order_by([e], desc: e.inserted_at, desc: e.id)
  end

  defp status_query do
    latest_event_query()
    |> select([e], %{execution_id: e.execution_id, status: e.type})
  end
end
