defmodule TdDd.Search.EnricherBehaviour do
  @moduledoc """
  Behaviour defining operations to enrich data structure versions
  """
  alias TdDd.DataStructures.DataStructureVersion

  @callback async_enrich_versions(
              chunked_ids_stream :: any(),
              relation_type_id :: any(),
              filters :: any()
            ) :: [DataStructureVersion.t()]
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

  def enrich_versions(ids, relation_type_id, filters) do
    result =
      DataStructures.enriched_structure_versions(
        ids: ids,
        relation_type_id: relation_type_id,
        content: :searchable,
        filters: filters,
        # Protected metadata is not indexed
        with_protected_metadata: false
      )

    chunk_size = Enum.count(ids)
    Tasks.log_progress(chunk_size)

    result
  end
end
