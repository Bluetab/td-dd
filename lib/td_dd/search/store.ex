defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantStructure
  alias TdDd.Repo

  alias TdDd.Search.Tasks

  require Logger

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  @impl true
  def stream(DataStructureVersion) do
    dsv_count = Repo.aggregate(DataStructureVersion, :count, :id)
    Tasks.log_start_stream(dsv_count)

    DataStructureQueries.data_structure_version_ids()
    |> do_stream()
  end

  @impl true
  def stream(GrantStructure) do
    grants_count = Repo.aggregate(Grant, :count, :id)
    Tasks.log_start_stream(grants_count)

    DataStructureQueries.children()
    |> do_stream_grants()
  end

  def stream(DataStructureVersion, data_structure_ids) do
    dsv_count = Enum.count(data_structure_ids)
    Tasks.log_start_stream(dsv_count)

    [data_structure_ids: data_structure_ids]
    |> DataStructureQueries.data_structure_version_ids()
    |> do_stream()
  end

  def stream(GrantStructure, grant_ids) do
    grants_count = Enum.count(grant_ids)
    Tasks.log_start_stream(grants_count)

    [grant_ids: grant_ids]
    |> DataStructureQueries.children()
    |> do_stream_grants()
  end

  defp do_stream(query) do
    relation_type_id = RelationTypes.default_id!()
    filters = DataStructureTypes.metadata_filters()

    query
    |> Repo.stream()
    |> Stream.chunk_every(chunk_size())
    |> Stream.flat_map(&enrich_chunk_data_structures(&1, relation_type_id, filters))
  end

  defp do_stream_grants(query) do
    relation_type_id = RelationTypes.default_id!()
    users = TdCache.UserCache.map()
    filters = DataStructureTypes.metadata_filters()

    query
    |> Repo.stream()
    |> Stream.chunk_every(chunk_size())
    |> Stream.flat_map(&enrich_chunk_grant_structures(&1, relation_type_id, filters, users))
  end

  defp enrich_chunk_data_structures(ids, relation_type_id, filters) do
    result = enriched_structure_versions(ids, relation_type_id, filters)

    chunk_size = Enum.count(ids)
    Tasks.log_progress(chunk_size)

    result
  end

  defp enriched_structure_versions(ids, relation_type_id, filters) do
    DataStructures.enriched_structure_versions(
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable,
      filters: filters,
      # Protected metadata is not indexed
      with_protected_metadata: false
    )
  end

  defp streamed_enriched_structure_versions(ids, relation_type_id, filters) do
    DataStructures.streamed_enriched_structure_versions(
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable,
      filters: filters,
      # Protected metadata is not indexed
      with_protected_metadata: false
    )
  end

  defp enrich_chunk_grant_structures(grant_structures_chunk, relation_type_id, filters, users) do
    grants_map =
      Map.new(grant_structures_chunk, fn %{grant: %{id: id} = grant} ->
        {id, Map.put(grant, :user, Map.get(users, grant.user_id))}
      end)

    structure_grant_ids =
      grant_structures_chunk
      |> Enum.flat_map(fn %{grant: %{id: grant_id}, dsv_children: dsv_children} ->
        Enum.map(dsv_children, &%{dsv_id: &1, grant_id: grant_id})
      end)
      |> Enum.group_by(& &1.dsv_id, & &1.grant_id)

    result =
      grant_structures_chunk
      |> Enum.flat_map(fn %{dsv_children: children} -> children end)
      |> streamed_enriched_structure_versions(relation_type_id, filters)
      |> Stream.flat_map(fn %{id: dsv_id} = dsv ->
        structure_grant_ids
        |> Map.get(dsv_id)
        |> Enum.map(fn grant_id ->
          %GrantStructure{
            grant: Map.get(grants_map, grant_id),
            data_structure_version: dsv
          }
        end)
      end)

    # structures =
    #   grant_structures_chunk
    #   |> Enum.flat_map(fn %{dsv_children: children} -> children end)
    #   |> enriched_structure_versions(relation_type_id, filters)
    #   |> Map.new(fn %{id: id} = dsv -> {id, dsv} end)

    # result =
    #   Stream.flat_map(
    #     grant_structures_chunk,
    #     fn %{grant: grant, dsv_children: children} ->
    #       Enum.map(
    #         children,
    #         fn dsv_id ->
    #           %GrantStructure{
    #             grant: Map.put(grant, :user, Map.get(users, grant.user_id)),
    #             data_structure_version: Map.get(structures, dsv_id)
    #           }
    #         end
    #       )
    #     end
    #   )

    chunk_size = Enum.count(grant_structures_chunk)
    Tasks.log_progress(chunk_size)

    result
  end

  defp chunk_size, do: Application.get_env(__MODULE__, :chunk_size, 1000)

  def vacuum do
    Repo.vacuum([
      "data_structures",
      "data_structure_relations",
      "data_structure_types",
      "data_structure_versions",
      "relation_types",
      "sources",
      "structure_metadata",
      "structure_classifications",
      "systems",
      "tags"
    ])
  end
end
