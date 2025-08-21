defmodule TdDd.XLSX.Upload do
  @moduledoc """
    Handles the processing and bulk updating of data from XLSX files.

    This module provides functionality to read and process an XLSX file using
    the `TdDd.XLSX.Reader` module and then applies bulk updates using
    `TdDd.DataStructures.BulkUpdate`.

    ## Functions

    - `structures/2`: Parses an XLSX file and applies bulk updates.
    - `structures_async/3`: Creates an oban job for async xlsx processing.
  """

  alias Oban
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.FileBulkUpdateEvents
  alias TdDd.XLSX.Jobs.UploadWorker
  alias TdDd.XLSX.Reader

  require Logger

  @file_upload_dir Application.compile_env(:td_dd, :file_upload_dir)

  def structures(%{path: path, file_name: file_name, hash: hash} = params, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:is_strict_update, true)
      |> Keyword.put(:store_events, true)
      |> Keyword.put(:merge_content, true)
      |> Keyword.put(:upload_params, params)

    with {:parsed, {rows, external_id_errors}} when is_list(rows) <-
           {:parsed, Reader.parse(path, opts)},
         {:structures_without_permissions, []} <-
           {:structures_without_permissions,
            BulkUpdate.reject_rows(
              rows,
              opts[:auto_publish],
              opts[:claims]
            )} do
      BulkUpdate.file_bulk_update(rows, external_id_errors, opts[:user_id], opts)
    else
      {:structures_without_permissions, [_ | _]} ->
        FileBulkUpdateEvents.create_failed(
          opts[:user_id],
          hash,
          file_name,
          "forbidden",
          opts[:task_reference]
        )

        {:cancel, :forbidden}

      {:parsed, {:error, %{message: :external_id_not_found}} = error} ->
        FileBulkUpdateEvents.create_failed(
          opts[:user_id],
          hash,
          file_name,
          "external_id_not_found",
          opts[:task_reference]
        )

        error

      {:parsed, {:error, :template_not_found} = error} ->
        FileBulkUpdateEvents.create_failed(
          opts[:user_id],
          hash,
          file_name,
          "template_not_found",
          opts[:task_reference]
        )

        error

      other_error ->
        Logger.error("Upload error: #{inspect(other_error)}")

        error_message =
          case other_error do
            {:parsed, {:error, %{message: msg}}} ->
              "Please contact Truedat's team: #{inspect(msg)}"

            _ ->
              "Please contact Truedat's team: #{inspect(other_error)}"
          end

        FileBulkUpdateEvents.create_failed(
          opts[:user_id],
          hash,
          file_name,
          error_message,
          opts[:task_reference]
        )

        other_error
    end
  end

  def structures_async(%{path: path, filename: file_name}, hash, opts) do
    file_path = copy_file(path, opts)

    %{path: file_path, file_name: file_name, hash: hash, opts: opts}
    |> UploadWorker.new()
    |> Oban.insert()
  end

  defp copy_file(path, opts) do
    upload_dir = Map.get(opts, "upload_dir", @file_upload_dir)
    :ok = File.mkdir_p!(upload_dir)
    source_file_name = path |> Path.split() |> List.last()
    file_path = Path.join([upload_dir, source_file_name])
    :ok = File.cp!(path, file_path)
    file_path
  end
end
