defmodule TdDd.XLSX.UploadWorker do
  @moduledoc """
  Oban worker for Structure Notes XLSX file uploads
  """
  use Oban.Worker,
    queue: :xlsx_notes_upload_queue,
    max_attempts: 1

  alias TdCore.XLSX.UploadWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    UploadWorker.run(args)
  end
end
