defmodule TdDq.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Executions.Audit
  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group
  alias TdDq.Implementations.ImplementationQueries

  @pagination_params [:order_by, :limit, :before, :after]

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

    params = cast(params)

    params
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

      {:sources, external_ids}, q ->
        sources_query = ImplementationQueries.implementation_sources_query(external_ids)
        join(q, :inner, [e], s in ^sources_query, on: e.implementation_id == s.implementation_id)

      _, q ->
        q
    end)
    |> order_by(:id)
    |> preload(^preloads)
    |> Repo.all()
  end

  defp cast(%{} = params) do
    types = %{
      group_id: :integer,
      execution_group_id: :integer,
      status: :string,
      source: :string,
      sources: {:array, :string}
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
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: Dataloader.default_timeout())
  end

  defp query(queryable, params) do
    Enum.reduce(params, queryable, fn _, q -> q end)
  end
end
