defmodule TdDd.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.Executions.Audit
  alias TdDd.Executions.ProfileExecution
  alias TdDd.Executions.ProfileGroup
  alias TdDd.Repo

  @doc """
  Fetches the `Execution` with the given id.
  """
  def get_profile_execution(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    ProfileExecution
    |> preload(^preloads)
    |> Repo.get(id)
    |> enrich(opts[:enrich])
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
        |> join(:left, [e], p in assoc(e, :profile), as: :profile)
        |> join(:left, [e], pe in assoc(e, :profile_events), as: :profile_execution)
        |> where([profile: p], is_nil(p.id))
        |> where([profile_execution: pe], is_nil(pe.profile_execution_id))

      {:source, source_external_id}, q ->
        filter_by_source(q, [source_external_id])

      {:sources, source_external_ids}, q ->
        filter_by_source(q, source_external_ids)

      _, q ->
        q
    end)
    |> order_by(:id)
    |> preload(^preloads)
    |> Repo.all()
  end

  defp filter_by_source(query, source_external_ids) do
    query
    |> join(:left, [e], ds in assoc(e, :data_structure), as: :data_structure)
    |> join(:left, [data_structure: ds], s in assoc(ds, :source), as: :source)
    |> where([source: s], s.external_id in ^source_external_ids)
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

  def update_all(structure_id, profile_id) do
    ProfileExecution
    |> where([p], is_nil(p.profile_id))
    |> where([p], p.data_structure_id == ^structure_id)
    |> select([p], p.id)
    |> Repo.update_all(set: [profile_id: profile_id])
  end

  defp do_create_profile_group(%Changeset{} = changeset) do
    Multi.new()
    |> Multi.insert(:profile_group, changeset)
    |> Multi.run(:audit, Audit, :execution_group_created, [changeset])
    |> Repo.transaction()
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

  defp get_latest_version(%ProfileExecution{data_structure: structure = %{id: id}}) do
    structure
    |> DataStructures.get_latest_version()
    |> case do
      nil ->
        nil

      dsv ->
        parents =
          dsv
          |> DataStructures.get_ancestors()
          |> Enum.map(fn %{id: data_structure_id, name: name} ->
            %{data_structure_id: data_structure_id, name: name}
          end)
          |> Enum.reverse()

        path = parents ++ [%{data_structure_id: id, name: dsv.name}]

        %{dsv | path: path}
    end
  end

  defp get_latest_version(_execution), do: nil

  defp enrich(%{} = target, options, key, fun) do
    case Enum.member?(options, key) do
      false -> target
      true -> Map.put(target, key, fun.(target))
    end
  end
end
