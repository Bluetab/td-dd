defmodule TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsDeletion do
  @moduledoc """
  Deletes stale record embeddings.
  """

  use Oban.Worker, queue: :embedding_deletion, max_attempts: 5

  alias TdDd.DataStructures.RecordEmbeddings

  require Logger

  def perform(%Oban.Job{}) do
    case RecordEmbeddings.delete_stale_record_embeddings() do
      {:ok,
       %{
         from_disabled_indices: {disabled_count, _disabled},
         from_deleted_data_structure_versions: {deleted_count, _deleted}
       }} ->
        Logger.info("Deleted #{disabled_count + deleted_count} record embeddings")

      {count, nil} when is_integer(count) ->
        Logger.info("Deleted #{count} record embeddings")

      {:error, error} ->
        Logger.error("Unexpected error #{inspect(error)} occurred")
    end
  end
end
