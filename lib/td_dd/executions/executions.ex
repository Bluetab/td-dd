defmodule TdDd.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Executions.{Audit, ProfileExecution, ProfileGroup}
  alias TdDd.Repo

  @doc """
  Fetches the `Execution` with the given id.
  """
  def get_profile_execution(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    ProfileExecution
    |> preload(^preloads)
    |> Repo.get(id)
  end

  @doc """
  Returns an execution group.
  """
  def get_profile_group(%{"id" => id} = _params, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    ProfileGroup
    |> preload(^preloads)
    |> Repo.get(id)
    |> enrich(opts[:enrich])
  end

  @doc """
  Returns a list of execution groups.
  """
  def list_profile_groups(params \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    params
    |> Enum.reduce(ProfileGroup, fn
      {:created_by_id, id}, q -> where(q, [g], g.created_by_id == ^id)
    end)
    |> preload(^preloads)
    |> Repo.all()
  end

  @doc """
  Returns a list of executions.
  """
  def list_profile_executions(params \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    params = cast(params)

    params
    |> Enum.reduce(ProfileExecution, fn
      {:profile_group_id, id}, q ->
        where(q, [e], e.profile_group_id == ^id)

      {:execution_group_id, id}, q ->
        where(q, [e], e.profile_group_id == ^id)

      {:status, "pending"}, q ->
        q
        |> join(:left, [e], p in assoc(e, :profile))
        |> where([_e, p], is_nil(p.id))

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
      profile_group_id: :integer,
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
  def create_profile_group(%{} = params) do
    params
    |> ProfileGroup.changeset()
    |> do_create_profile_group()
  end

  defp do_create_profile_group(%Changeset{} = changeset) do
    Multi.new()
    |> Multi.insert(:profile_group, changeset)
    |> Multi.run(:audit, Audit, :execution_group_created, [changeset])
    |> Repo.transaction()
  end

  defp filter([_ | _] = executions, %{source: source}) do
    filter(executions, %{sources: [source]})
  end

  defp filter([_ | _] = executions, %{sources: sources}) do
    executions
    |> Enum.group_by(&get_source/1, & &1)
    |> Enum.filter(fn
      {source, _} -> source in sources
    end)
    |> Enum.flat_map(fn
      {_source, executions} -> executions
    end)
  end

  defp filter(executions, _params), do: executions

  defp get_source(%{data_structure: %DataStructure{} = structure}) do
    get_source(structure)
  end

  defp get_source(%DataStructure{} = structure) do
    structure
    |> DataStructures.get_latest_version()
    |> Map.get(:metadata)
    |> Map.get("alias")
  end

  defp get_source(execution) do
    execution
    |> Repo.preload(:data_structure)
    |> get_source()
  end

  defp enrich(group, nil), do: group

  defp enrich(nil, _opts), do: nil

  defp enrich(%ProfileGroup{executions: executions} = group, opts) when is_list(executions) do
    executions = Enum.map(executions, &enrich(&1, opts))
    Map.put(group, :executions, executions)
  end

  defp enrich(%ProfileExecution{} = execution, opts) do
    enrich(execution, opts, :latest, &get_latest_version/1)
  end

  defp get_latest_version(%ProfileExecution{data_structure: structure = %{}}) do
    DataStructures.get_latest_version(structure)
  end

  defp get_latest_version(_execution), do: nil

  defp enrich(%{} = target, options, key, fun) do
    case Enum.member?(options, key) do
      false -> target
      true -> Map.put(target, key, fun.(target))
    end
  end
end
