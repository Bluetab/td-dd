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
  alias TdDd.Grants.GrantStructure
  alias TdDd.Repo

  require Logger

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  @impl true
  def stream(DataStructureVersion) do
    DataStructureQueries.data_structure_version_ids()
    |> do_stream()
  end

  @impl true
  def stream(GrantStructure) do
    DataStructureQueries.children()
    |> do_stream_grants()
  end

  def stream(DataStructureVersion, data_structure_ids) do
    [data_structure_ids: data_structure_ids]
    |> DataStructureQueries.data_structure_version_ids()
    |> do_stream()
  end

  def stream(GrantStructure, grant_ids) do
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
    |> Stream.map(&enrich_chunk_data_structures(&1, relation_type_id, filters))
    |> Stream.flat_map(& &1)
  end

  defp do_stream_grants(query) do
    relation_type_id = RelationTypes.default_id!()
    users = TdCache.UserCache.map()
    filters = DataStructureTypes.metadata_filters()

    query
    |> Repo.stream()
    |> Stream.chunk_every(chunk_size())
    |> Stream.map(&enrich_chunk_grant_structures(&1, relation_type_id, filters, users))
    |> Stream.flat_map(& &1)
  end

  defp enrich_chunk_data_structures(ids, relation_type_id, filters) do
    DataStructures.enriched_structure_versions(
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable,
      filters: filters
    )
  end

  defp enrich_chunk_grant_structures(grant_structures_chunk, relation_type_id, filters, users) do
    Enum.flat_map(
      grant_structures_chunk,
      fn %{grant: grant, dsv_children: children} ->
        Enum.map(
          enrich_chunk_data_structures(children, relation_type_id, filters),
          fn dsv ->
            %GrantStructure{
              grant: Map.put(grant, :user, Map.get(users, grant.user_id)),
              data_structure_version: dsv
            }
          end
        )
      end
    )
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
