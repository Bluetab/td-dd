defmodule TdDd.DataStructures.DataStructureVersions.Workers.OutdatedEmbeddings do
  @moduledoc """
  Finds all DataStructureVersions whose RecordEmbedding is missing
  or older than the version’s own `updated_at`, and enqueues
  EmbedAndIndexBatch jobs in manageable chunks.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  require Logger

  alias TdDd.DataStructures.RecordEmbeddings

  @limit Application.compile_env(:td_dd, :limit_outdated_embeddings, 50_000)

  def perform(%Oban.Job{}) do
    [limit: @limit]
    |> RecordEmbeddings.upsert_outdated_async()
    |> then(fn
      {:ok, jobs} ->
        Logger.info("Inserted #{Enum.count(jobs)} jobs")

      :noop ->
        Logger.info("Worker canceled because all indices are disabled")
        {:cancel, :indices_disabled}
    end)
  end
end
