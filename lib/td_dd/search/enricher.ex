defmodule TdDd.Search.EnricherBehaviour do
  @moduledoc """
  Behaviour defining operations to enrich data structure versions
  """
  @callback async_enrich_versions(
              chunked_ids_stream :: any(),
              relation_type_id :: any(),
              filters :: any()
            ) :: Enumerable.t()
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
      max_concurrency: 2,
      timeout: :infinity
    )
    |> Stream.flat_map(fn {:ok, chunk} -> chunk end)
  end

  def enrich_versions(ids, relation_type_id, filters) do
    [
      ids: ids,
      relation_type_id: relation_type_id,
      content: :searchable,
      filters: filters,
      # Protected metadata is not indexed
      with_protected_metadata: false,
      preload: [:record_embeddings]
    ]
    |> DataStructures.enriched_structure_versions()
    |> tap(fn chunk ->
      chunk
      |> Enum.count()
      |> Tasks.log_progress()
    end)
  end
end
