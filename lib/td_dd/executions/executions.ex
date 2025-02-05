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

  @bulk_insertion_chunk 100
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
  def create_profile_group(_params, _opts \\ [])

  def create_profile_group(%{parent_structure_id: structure_id} = params, opts) do
    Multi.new()
    |> Multi.run(:structure, fn _repo, _params ->
      case DataStructures.get_data_structure(structure_id) do
        %DataStructures.DataStructure{} = structure -> {:ok, structure}
        nil -> {:error, :structure_not_found}
      end
    end)
    |> Multi.run(:data_structure_version, fn _repo, %{structure: structure} ->
      case DataStructures.get_latest_version(structure) do
        %DataStructures.DataStructureVersion{} = version -> {:ok, version}
        nil -> {:error, :version_not_found}
      end
    end)
    |> Multi.insert(
      :inserted_profile_group,
      params
      |> Map.delete(:parent_structure_id)
      |> ProfileGroup.changeset()
    )
    |> Multi.merge(fn %{data_structure_version: version, inserted_profile_group: profile_group} ->
      profile_executions_insertion(version, profile_group, opts)
    end)
    |> Multi.run(:profile_group, fn _repo, %{inserted_profile_group: profile_group} ->
      {:ok, Repo.preload(profile_group, executions: from(e in ProfileExecution, limit: 1_000))}
    end)
    |> Multi.run(:audit, Audit, :execution_group_created, [])
    |> Repo.transaction()
  end

  def create_profile_group(%{} = params, _opts) do
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

  defp profile_executions_insertion(data_structure_version, profile_group, opts) do
    date = DateTime.utc_now()
    timestamps = %{inserted_at: date, updated_at: date}

    data_structure_version
    |> DataStructures.stream_field_structures(opts)
    |> Stream.chunk_every(opts[:chunk_every] || @bulk_insertion_chunk)
    |> Enum.reduce(Multi.new(), fn [head | _tail] = chunk, multi ->
      Multi.insert_all(
        multi,
        {:chunk, head.id},
        ProfileExecution,
        Enum.map(chunk, &execution_params(&1, profile_group, timestamps))
      )
    end)
  end

  defp execution_params(data_field, profile_group, timestamps) do
    data_field
    |> Map.take([:data_structure_id])
    |> Map.put(:profile_group_id, profile_group.id)
    |> Map.merge(timestamps)
  end
end
