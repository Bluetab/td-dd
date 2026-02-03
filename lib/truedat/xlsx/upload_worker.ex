defmodule Truedat.XLSX.UploadWorker do
  @moduledoc """
  Oban worker for XLSX file uploads (implementations or structure notes).

  Dispatches to `Truedat.XLSX.BulkLoad` according to job scope.

  ## Functionality
  - Processes uploaded XLSX files asynchronously via Oban.
  - Supports a single attempt (max_attempts: 1) for processing.
  - Extracts job options (`lang`, `auto_publish`, `claims`) before processing.
  - Creates upload job events to track processing status (started, completed, failed).
  - Reads XLSX sheets using `Truedat.XLSX.Reader` and performs bulk load operations.

  (Moduledoc updated: worker is generic for implementations and structure notes, not implementations-only; reference to Truedat.XLSX.BulkLoad aligned with that.)
  """
  use Oban.Worker,
    queue: :xlsx_implementations_upload_queue,
    max_attempts: 1

  alias Truedat.Audit.UploadJobs
  alias Truedat.Auth.Claims
  alias Truedat.XLSX.BulkLoad
  alias Truedat.XLSX.Reader

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "path" => path,
          "job_id" => job_id,
          "scope" => scope,
          "opts" => %{
            "lang" => lang,
            "auto_publish" => auto_publish,
            "claims" => claims
          }
        }
      }) do
    impl_for =
      case scope do
        "implementations" -> struct(TdDq.Implementations.Implementation)
        "notes" -> struct(TdDd.DataStructures.StructureNote)
      end

    ctx = %{
      job_id: job_id,
      impl_for: impl_for,
      lang: lang,
      claims: Claims.coerce(claims),
      to_status: if(auto_publish == "true", do: "published", else: "draft")
    }

    UploadJobs.create_started(job_id)

    with {:ok, sheets} <- Reader.read(path),
         {:ok, result} <- BulkLoad.bulk_load(sheets, ctx) do
      UploadJobs.create_completed(job_id, result)
    else
      {:error, reason} -> UploadJobs.create_failed(job_id, reason)
    end
  end
end
