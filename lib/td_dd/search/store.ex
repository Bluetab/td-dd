defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo
  import Ecto.Query
  alias TdDd.Grants.Grant

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
  def stream(Grant) do
    relation_type_id = RelationTypes.default_id!()
    IO.puts("STREAM/1")
    Grant
    |> Repo.stream()
    |> Repo.stream_preload(1000, [data_structure_version: [:data_structure]])
    #|> IO.inspect(label: "STREAM_PRELOAD/1")
    #|> Stream.chunk_every(chunk_size())
    #|> Stream.map(&enrich_chunk(&1, relation_type_id))
  end


  def stream(Grant, ids) do
    IO.puts("STREAM/2")
    #IO.inspect(ids, label: "IDs")
    grants = from(grant in Grant)

    grants
    |> where([grant], grant.id in ^ids)
    |> select([grant], grant)
    |> Repo.stream()
    |> Repo.stream_preload(1000, [data_structure_version: [:data_structure]])
  end

  def stream(DataStructureVersion, data_structure_ids) do
    [data_structure_ids: data_structure_ids]
    |> DataStructureQueries.data_structure_version_ids()
    |> do_stream()
  end

  defp do_stream(query) do
    relation_type_id = RelationTypes.default_id!()

    query# |> IO.inspect(label: "query")
    |> Repo.stream()# |> IO.inspect(label: "Repo.stream()")
    |> Stream.chunk_every(chunk_size())# |> IO.inspect(label: "chunk_every")
    |> Stream.map(&enrich_chunk(&1, relation_type_id))# |> IO.inspect(label: "enrich_chunk")
    |> Stream.flat_map(& &1)# |> IO.inspect(label: "flat_map")
  end

  defp enrich_chunk(ids, relation_type_id) do
    #IO.inspect(ids, label: "enrich_chunk ids")
    #IO.inspect(relation_type_id, label: "enrich_chunk relation_type_id")
    DataStructures.enriched_structure_versions(
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable
    )
  end

  defp chunk_size, do: Application.get_env(__MODULE__, :chunk_size, 1000)

  def vacuum do
    Repo.vacuum([
      "data_structures",
      "data_structure_relations",
      "data_structure_tags",
      "data_structure_types",
      "data_structure_versions",
      "relation_types",
      "sources",
      "structure_metadata",
      "structure_classifications",
      "systems"
    ])
  end
end
