defmodule TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch do
  @moduledoc """
  Upsert embeddings in database given a list of data structure ids.
  """
  use Oban.Worker, queue: :embedding_upserts, max_attempts: 5

  require Logger

  alias TdDd.DataStructures.RecordEmbeddings

  def perform(%Oban.Job{args: %{"data_structure_ids" => data_structure_ids}}) do
    {count, nil} = RecordEmbeddings.upsert_from_structures(data_structure_ids)
    Logger.info("upserted #{count} record embeddings")
  end
end
