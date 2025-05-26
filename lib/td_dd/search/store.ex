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

  @enricher Application.compile_env(:td_dd, :search_enricher, TdDd.Search.EnricherImpl)

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

    []
    |> DataStructureQueries.children()
    |> do_stream_grants()
  end

  def stream(GrantRequest) do
    stream(GrantRequest, nil)
  end

  def stream(DataStructureVersion, :embeddings) do
    dsv_count = Repo.aggregate(DataStructureVersion, :count, :id)
    Tasks.log_start_stream(dsv_count)

    query = DataStructureQueries.data_structure_version_embeddings()

    query
    |> Repo.stream()
    |> Stream.chunk_every(128)
    |> @enricher.async_enrich_version_embeddings()
    |> Stream.reject(&is_nil(Map.get(&1, :embeddings)))
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
    grants_request_count = Repo.aggregate(GrantRequest, :count, :id)
    Tasks.log_start_stream(grants_request_count)
    users = TdCache.UserCache.map()
    status_subquery = status_subquery()
    approved_by_subquery = approved_by_subquery()

    chunk_size = chunk_size(:grant_request)

    schema
    |> join(:left, [gr], s in ^status_subquery, on: s.grant_request_id == gr.id)
    |> join(:left, [gr], gra in ^approved_by_subquery, on: gra.grant_request_id == gr.id)
    |> join(:left, [gr, _s, _gra], grant in assoc(gr, :grant))
    |> join(:left, [gr, _s, _gra, grant], dsv in assoc(grant, :data_structure_version))
    |> where_ids(ids)
    |> select(
      [gr, s, gra, grant, dsv],
      {
        %GrantRequest{
          gr
          | current_status: s.status,
            approved_by: gra.role,
            grant: grant
        },
        dsv
      }
    )
    |> Repo.stream()
    |> Stream.map(fn
      {%{grant: nil} = grant_request, _grant_dsv} ->
        grant_request

      {%{grant: %Grant{} = _grant} = grant_request, grant_dsv} ->
        Kernel.put_in(grant_request.grant.data_structure_version, grant_dsv)
    end)
    |> Repo.stream_preload(1000, :group)
    |> Stream.chunk_every(chunk_size)
    |> Stream.flat_map(&enrich_chunk_grant_request_structures(&1, users))
  end

  defp where_ids(query, ids) when is_list(ids) do
    where(query, [gr], gr.id in ^ids)
  end

  defp where_ids(query, nil), do: query

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
    chunk_size = chunk_size(:data_structure)

    query
    |> Repo.stream()
    |> Stream.chunk_every(chunk_size)
    |> @enricher.async_enrich_versions(relation_type_id, filters)
  end

  defp do_stream_grants(query) do
    relation_type_id = RelationTypes.default_id!()
    users = TdCache.UserCache.map()
    filters = DataStructureTypes.metadata_filters()

    chunk_size = chunk_size(:grants)

    query
    |> Repo.stream()
    |> Stream.chunk_every(chunk_size)
    |> Stream.flat_map(&enrich_chunk_grant_structures(&1, relation_type_id, filters, users))
  end

  defp streamed_enriched_structure_versions(ids, relation_type_id, filters) do
    DataStructures.streamed_enriched_structure_versions(
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable,
      filters: filters,
      # Protected metadata is not indexed
      with_protected_metadata: false,
      chunk_size: chunk_size(:data_structure_version)
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
      |> Enum.map(fn
        %{data_structure_id: structure_id} when not is_nil(structure_id) ->
          structure_id

        %{grant: %{data_structure_id: grant_dsid}} when not is_nil(grant_dsid) ->
          grant_dsid
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
          |> maybe_update_grant_dsv(dsv_with_ds_index)
          |> Map.put(:user, Map.get(users, user_id))
          |> Map.put(:created_by, Map.get(users, created_by_id))
        end
      )

    chunk_size = Enum.count(grant_request_chunks)

    Tasks.log_progress(chunk_size)

    result
  end

  defp maybe_update_grant_dsv(
         %{grant: %{data_structure_id: grant_dsid}} = grant_request,
         dsv_with_ds_index
       ) do
    Kernel.put_in(
      grant_request.grant.data_structure_version,
      Map.get(dsv_with_ds_index, grant_dsid)
    )
  end

  defp maybe_update_grant_dsv(grant_request, _), do: grant_request

  defp chunk_size(key),
    do: Application.get_env(:td_dd, __MODULE__)[key]

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
