defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Grants.GrantRequestStatus
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

  @impl true
  def stream(GrantRequest = schema) do
    grants_request_count = Repo.aggregate(GrantRequest, :count, :id)
    Tasks.log_start_stream(grants_request_count)
    users = TdCache.UserCache.map()
    status_subquery = status_subquery()
    approved_by_subquery = approved_by_subquery()

    schema
    |> join(:left, [gr], s in ^status_subquery, on: s.grant_request_id == gr.id)
    |> join(:left, [gr], gra in ^approved_by_subquery, on: gra.grant_request_id == gr.id)
    |> select([gr, s, gra], %GrantRequest{gr | current_status: s.status, approved_by: gra.role})
    |> Repo.stream()
    |> Repo.stream_preload(1000, :group)
    |> Stream.chunk_every(chunk_size())
    |> Stream.flat_map(&enrich_chunk_grant_request_structures(&1, users))
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

  def stream(GrantRequest = schema, ids) do
    grants_request_count = Enum.count(ids)
    Tasks.log_start_stream(grants_request_count)
    users = TdCache.UserCache.map()

    status_subquery = status_subquery()
    approved_by_subquery = approved_by_subquery()

    schema
    |> join(:left, [gr], s in ^status_subquery, on: s.grant_request_id == gr.id)
    |> join(:left, [gr], gra in ^approved_by_subquery, on: gra.grant_request_id == gr.id)
    |> where([gr], gr.id in ^ids)
    |> select([gr, s, gra], %GrantRequest{gr | current_status: s.status, approved_by: gra.role})
    |> Repo.stream()
    |> Repo.stream_preload(1000, :group)
    |> Stream.chunk_every(chunk_size())
    |> Stream.flat_map(&enrich_chunk_grant_request_structures(&1, users))
  end

  defp status_subquery do
    GrantRequestStatus
    |> distinct([s], s.grant_request_id)
    |> order_by([s], desc: s.inserted_at)
    |> subquery()
  end

  defp approved_by_subquery do
    GrantRequestApproval
    |> group_by([g], g.grant_request_id)
    |> select([g], %{
      grant_request_id: g.grant_request_id,
      role: fragment("ARRAY_AGG(DISTINCT ?)", g.role)
    })
    |> subquery()
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

    chunk_size = Enum.count(grant_structures_chunk)
    Tasks.log_progress(chunk_size)

    result
  end

  defp enrich_chunk_grant_request_structures(grant_request_chunks, users) do
    structure_ids =
      grant_request_chunks
      |> Enum.map(fn %{data_structure_id: structure_id} ->
        structure_id
      end)
      |> Enum.uniq()

    dsv_with_ds_index =
      DataStructures.enriched_structure_versions(
        data_structure_ids: structure_ids,
        content: :searchable,
        # Protected metadata is not indexed
        with_protected_metadata: false
      )
      |> Map.new(fn %{data_structure_id: structure_id} = dsv ->
        {structure_id, dsv}
      end)

    result =
      Enum.map(
        grant_request_chunks,
        fn %{
             data_structure_id: structure_id,
             group: %{user_id: user_id, created_by_id: created_by_id}
           } = grant_request ->
          grant_request
          |> Map.put(:data_structure_version, Map.get(dsv_with_ds_index, structure_id))
          |> Map.put(:user, Map.get(users, user_id))
          |> Map.put(:created_by, Map.get(users, created_by_id))
        end
      )

    chunk_size = Enum.count(grant_request_chunks)

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
