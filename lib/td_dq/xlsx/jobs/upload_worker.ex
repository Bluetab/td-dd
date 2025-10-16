defmodule TdDq.XLSX.Jobs.UploadWorker do
  @moduledoc """
  An Oban worker responsible for processing XLSX file uploads for quality rule implementations.

  This worker is enqueued when an XLSX file is uploaded and executes
  the processing logic asynchronously using `TdDq.XLSX.BulkLoad`.

  ## Functionality
  - Processes uploaded XLSX files asynchronously via Oban.
  - Supports a single attempt (max_attempts: 1) for processing.
  - Extracts job options (`lang`, `auto_publish`, `claims`) before processing.
  - Creates upload events to track processing status (started, completed, failed).
  - Reads XLSX sheets using `Truedat.XLSX.Reader` and performs bulk load operations.
  """
  use Oban.Worker,
    queue: :xlsx_implementations_upload_queue,
    max_attempts: 1

  alias TdDq.Implementations.UploadEvents
  alias TdDq.XLSX.BulkLoad

  alias Truedat.Auth.Claims
  alias Truedat.XLSX.Reader

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "path" => path,
          "job_id" => job_id,
          "opts" => %{
            "lang" => lang,
            "auto_publish" => auto_publish,
            "claims" => claims
          }
        }
      }) do
    ctx = %{
      job_id: job_id,
      lang: lang,
      to_status: if(auto_publish == "true", do: "published", else: "draft"),
      claims: Claims.coerce(claims)
    }

    UploadEvents.create_started(job_id)

    with {:ok, sheets} <- Reader.read(path),
         {:ok, result} <- BulkLoad.bulk_load(sheets, ctx) do
      UploadEvents.create_completed(job_id, result)
    else
      {:error, reason} -> UploadEvents.create_failed(job_id, reason)
    end
  end
end
