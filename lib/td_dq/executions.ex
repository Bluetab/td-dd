defmodule TdDq.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Executions.{Audit, Execution, Group}
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation

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
  def list_groups(params \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    params
    |> Enum.reduce(Group, fn
      {:created_by_id, id}, q -> where(q, [g], g.created_by_id == ^id)
    end)
    |> preload(^preloads)
    |> Repo.all()
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
        |> join(:left, [e], r in assoc(e, :result))
        |> where([_e, r], is_nil(r.id))

      _, q ->
        q
    end)
    |> order_by(:id)
    |> preload(^preloads)
    |> Repo.all()
    |> filter(params)
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
    |> Changeset.apply_changes()
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
    |> Multi.run(:audit, Audit, :execution_group_created, [changeset])
    |> Repo.transaction()
  end

  defp filter([_ | _] = executions, %{source: source}) do
    filter(executions, %{sources: [source]})
  end

  defp filter([_ | _] = executions, %{sources: sources}) do
    sorted_sources = Enum.sort(sources)

    executions
    |> Enum.group_by(&get_sources/1, & &1)
    |> Enum.filter(fn
      {[source], _} -> source in sources
      {sources, _} -> Enum.sort(sources) == sorted_sources
    end)
    |> Enum.flat_map(fn
      {sources, executions} -> Enum.map(executions, &Map.put(&1, :structure_aliases, sources))
    end)
  end

  defp filter(executions, _params), do: executions

  defp get_sources(%{implementation: implementation = %Implementation{}}) do
    Implementations.get_sources(implementation)
  end

  defp get_sources(execution) do
    execution
    |> Repo.preload(:implementation)
    |> Map.get(:implementation)
    |> Implementations.get_sources()
  end
end
