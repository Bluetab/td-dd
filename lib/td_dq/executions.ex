defmodule TdDq.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDq.Executions.{Audit, Execution, Group}
  alias TdDq.Repo
  alias TdDq.Rules.Implementations
  alias TdDq.Rules.Implementations.Implementation

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
    params = Map.Helpers.atomize_keys(params)
    preloads = Keyword.get(opts, :preload, [])

    params
    |> Enum.reduce(Execution, fn
      {:group_id, id}, q -> where(q, [e], e.group_id == ^id)
      {:execution_group_id, id}, q -> where(q, [e], e.group_id == ^id)
      _, q -> q
    end)
    |> where_status(params)
    |> preload(^preloads)
    |> Repo.all()
    |> filter(params)
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

  defp where_status(query, %{status: status}) do
    case String.downcase(status) do
      "pending" ->
        query
        |> join(:left, [e], r in assoc(e, :result))
        |> where([_e, r], is_nil(r.execution_id))

      _ ->
        query
    end
  end

  defp where_status(query, _params), do: query

  defp filter([_ | _] = executions, %{source: source}) do
    executions
    |> Enum.map(
      &Map.put(
        &1,
        :structure_aliases,
        get_sources(&1)
      )
    )
    |> Enum.filter(&(source in Map.get(&1, :structure_aliases)))
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
