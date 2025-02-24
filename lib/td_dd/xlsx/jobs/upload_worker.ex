defmodule TdDd.XLSX.Jobs.UploadWorker do
  @moduledoc """
  An Oban worker responsible for processing XLSX file uploads.

  This worker is enqueued when an XLSX file is uploaded and executes
  the processing logic asynchronously using `TdDd.XLSX.Upload`.

  ## Functionality
  - Ensures uniqueness based on the job `hash`, preventing duplicate processing.
  - Processes uploaded XLSX files asynchronously via Oban.
  - Supports retry attempts (up to 5) in case of failures.
  - Extracts job options (`user_id`, `lang`, `auto_publish`) before processing.
  """
  use Oban.Worker,
    queue: :xlsx_upload_queue,
    max_attempts: 5,
    unique: [
      fields: [:args, :worker],
      keys: [:hash],
      states: Oban.Job.states() -- [:cancelled, :discarded, :completed]
    ]

  alias TdDd.DataStructures.FileBulkUpdateEvents
  alias TdDd.XLSX.Upload
  alias Truedat.Auth.Claims

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "hash" => hash,
          "path" => path,
          "file_name" => file_name,
          "opts" => opts
        },
        attempt: attempt,
        max_attempts: max
      }) do
    task_reference = "oban:#{id}"

    opts =
      opts
      |> Keyword.new(fn
        {"user_id", user_id} -> {:user_id, user_id}
        {"lang", lang} -> {:lang, lang}
        {"auto_publish", auto_publish} -> {:auto_publish, auto_publish}
        {"claims", claims} -> {:claims, Claims.coerce(claims)}
      end)
      |> Keyword.put(:task_reference, task_reference)

    create_init_event(attempt, task_reference, opts[:user_id], hash, file_name)

    %{hash: hash, path: path, file_name: file_name}
    |> Upload.structures(opts)
    |> tap(fn
      {:ok, _response} -> File.rm!(path)
      {:cancel, :forbidden} -> File.rm!(path)
      _error when attempt == max -> File.rm!(path)
      _error -> :noop
    end)
    |> then(fn
      {:ok, _response} -> :ok
      error -> error
    end)
  end

  defp create_init_event(1, task_reference, user_id, hash, file_name) do
    FileBulkUpdateEvents.create_started(user_id, hash, file_name, task_reference)
  end

  defp create_init_event(attempt, task_reference, user_id, hash, file_name) when attempt > 1 do
    FileBulkUpdateEvents.create_retrying(user_id, hash, file_name, task_reference)
  end
end
