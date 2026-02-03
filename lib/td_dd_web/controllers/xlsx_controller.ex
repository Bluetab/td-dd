defmodule TdDdWeb.DataStructures.XLSXController do
  use TdDdWeb, :controller

  alias TdCore.Utils.FileHash
  alias TdDd.DataStructures.Search
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.XLSX.Download
  alias Truedat.Audit.UploadJobs
  alias Truedat.XLSX.Reader
  alias Truedat.XLSX.UploadWorker
  plug(TdDdWeb.SearchPermissionPlug)
  action_fallback(TdDdWeb.FallbackController)

  require Logger

  @default_lang Application.compile_env(:td_dd, :lang)
  @file_upload_dir Application.compile_env(:td_dd, :file_upload_dir)

  def download(conn, params) do
    structure_url_schema = Map.get(params, "structure_url_schema", nil)
    opts = build_opts(params)

    params =
      Map.drop(params, [
        "page",
        "size",
        "structure_url_schema",
        "download_type",
        "note_type",
        "lang",
        "header_labels"
      ])

    permission = conn.assigns[:search_permission]
    claims = conn.assigns[:current_resource]

    with %{results: [_ | _] = data_structures} <-
           search_all_structures(claims, permission, params),
         {:ok, {file_name, blob}} <-
           Download.write_to_memory(data_structures, structure_url_schema, opts) do
      send_xlsx_file(conn, file_name, blob)
    else
      %{results: []} -> send_resp(conn, :no_content, "")
    end
  end

  def upload(conn, params) do
    lang = Map.get(params, "lang", @default_lang)

    %{"structures" => %{path: file_path, filename: filename}} =
      params

    claims = conn.assigns[:current_resource]
    path = Reader.move_file!(file_path, @file_upload_dir)
    hash = FileHash.hash(path, :md5)

    opts = %{
      "auto_publish" => Map.get(params, "auto_publish"),
      "lang" => lang,
      "claims" => claims
    }

    scope = "notes"

    {:ok, %{id: job_id}} =
      UploadJobs.create_job(%{
        user_id: claims.user_id,
        hash: hash,
        filename: filename,
        scope: scope
      })

    with :ok <- Bodyguard.permit(StructureNotes, :xlsx_upload, claims, nil),
         {:ok, _} <- UploadJobs.create_pending(job_id) do
      %{path: path, job_id: job_id, scope: scope, opts: opts}
      |> UploadWorker.new()
      |> Oban.insert()

      json(conn, %{job_id: job_id})
    else
      {:error, reason} ->
        UploadJobs.create_failed(job_id, reason)
        {:error, reason}
    end
  end

  defp send_xlsx_file(conn, file_name, blob) do
    conn
    |> put_resp_content_type(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"
    )
    |> put_resp_header("content-disposition", "attachment; filename=#{file_name}")
    |> send_resp(:ok, blob)
  end

  defp search_all_structures(claims, permission, params) do
    Logger.info("Start searching all structures")

    Timer.time(
      fn ->
        include_children = to_string(Map.get(params, "include_children", false))
        data_structure_id = Map.get(params, "data_structure_id")

        params
        |> Map.put("without", "deleted_at")
        |> maybe_put_structure_filters(data_structure_id, include_children)
        |> Map.drop(["page", "size", "data_structure_id", "include_children"])
        |> Search.scroll_data_structures(claims, permission)
      end,
      fn ms, _ -> Logger.info("Searching all structures in #{ms} ms") end
    )
  end

  defp maybe_put_structure_filters(params, nil, _include_children), do: params

  defp maybe_put_structure_filters(params, data_structure_id, "false") do
    Map.put(params, "must", %{"data_structure_id" => data_structure_id})
  end

  defp maybe_put_structure_filters(params, data_structure_id, "true") do
    Map.put(params, "filters", %{
      "should" => %{
        "data_structure_id" => [data_structure_id],
        "parent_id" => [data_structure_id]
      }
    })
  end

  defp build_opts(params) do
    params
    |> Map.take(["download_type", "note_type", "lang", "header_labels"])
    |> Keyword.new(fn
      {"download_type", "editable"} -> {:download_type, :editable}
      {"note_type", "published"} -> {:note_type, :published}
      {"note_type", "non_published"} -> {:note_type, :non_published}
      {"header_labels", header_labels} -> {:header_labels, header_labels}
      {"lang", lang} -> {:lang, lang}
    end)
    |> Keyword.put_new(:lang, @default_lang)
    |> Keyword.put_new(:header_labels, %{})
  end
end
