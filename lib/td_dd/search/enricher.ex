defmodule TdDd.Search.EnricherBehaviour do
  @moduledoc """
  Behaviour defining operations to enrich data structure versions
  """
  @callback async_enrich_versions(
              chunked_ids_stream :: any(),
              relation_type_id :: any(),
              filters :: any()
            ) :: Enumerable.t()

  @callback async_enrich_version_embeddings(versions_stream :: Enumerable.t()) :: Enumerable.t()
end

defmodule TdDd.Search.EnricherImpl do
  @moduledoc """
  Implementation of behaviour `TdDd.Search.EnricherBehaviour`
  """
  @behaviour TdDd.Search.EnricherBehaviour

  alias TdDd.DataStructures
  alias TdDd.Search.Tasks

  def async_enrich_versions(chunked_ids_stream, relation_type_id, filters) do
    chunked_ids_stream
    |> Task.async_stream(&enrich_versions(&1, relation_type_id, filters),
      max_concurrency: 16,
      timeout: 20_000
    )
    |> Stream.flat_map(fn {:ok, chunk} -> chunk end)
  end

  def async_enrich_version_embeddings(versions_stream) do
    versions_stream
    |> Task.async_stream(&enrich_embeddings/1, max_concurrency: 16, timeout: 80_000)
    |> Stream.flat_map(fn {:ok, chunk} -> chunk end)
  end

  def enrich_versions(ids, relation_type_id, filters) do
    [
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable,
      filters: filters,
      # Protected metadata is not indexed
      with_protected_metadata: false
    ]
    |> DataStructures.enriched_structure_versions()
    |> tap(fn chunk ->
      chunk
      |> Enum.count()
      |> Tasks.log_progress()
    end)
  end

  defp enrich_embeddings(data_structure_versions) do
    {:ok, embeddings} =
      data_structure_versions
      |> Enum.map(&DataStructures.enriched_structure_version(&1, content: :searchable))
      |> DataStructures.embeddings()

    embeddings
    |> Enum.reduce(data_structure_versions, fn {collection_name, vectors}, acc ->
      embeddings_for_collection(collection_name, vectors, acc)
    end)
    |> tap(fn chunk ->
      chunk
      |> Enum.count()
      |> Tasks.log_progress()
    end)
  end

  defp embeddings_for_collection(collection_name, vectors, data_structure_versions) do
    Enum.zip_with([data_structure_versions, vectors], fn [data_structure_version, vector] ->
      embeddings =
        Map.put(data_structure_version.embeddings || %{}, "vector_#{collection_name}", vector)

      Map.put(data_structure_version, :embeddings, embeddings)
    end)
  end
end
