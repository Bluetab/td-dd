defmodule TdDqWeb.Implementation.XLSXController do
  use TdDqWeb, :controller

  alias TdCluster.Cluster.TdAudit.UploadJobs
  alias TdCore.Utils.FileHash
  alias TdCore.XLSX.Reader
  alias TdDq.Implementations
  alias TdDq.Implementations.Search
  alias TdDq.XLSX.Download
  alias TdDq.XLSX.UploadWorker

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  @file_upload_dir Application.compile_env(:td_dd, :file_upload_dir)
  @default_lang Application.compile_env(:td_dd, :lang)

  def download(conn, params) do
    opts = build_opts(params)

    params =
      Map.drop(params, [
        "page",
        "size",
        "impl_status",
        "header_labels",
        "content_labels"
      ])

    claims = conn.assigns[:current_resource]

    with %{results: [_ | _] = implementations} <-
           search_all_implementations(claims, params),
         {:ok, {file_name, blob}} <-
           Download.write_to_memory(implementations, opts) do
      conn
      |> put_resp_content_type(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;"
      )
      |> put_resp_header("content-disposition", "attachment; filename=#{file_name}")
      |> send_resp(:ok, blob)
    else
      %{results: []} -> send_resp(conn, :no_content, "")
    end
  end

  def upload(conn, params) do
    lang = Map.get(params, "lang", @default_lang)
    %{"implementations" => %{path: file_path, filename: filename}} = params
    claims = conn.assigns[:current_resource]
    path = Reader.move_file!(file_path, @file_upload_dir)
    hash = FileHash.hash(path, :md5)

    opts = %{
      "auto_publish" => Map.get(params, "auto_publish"),
      "lang" => lang,
      "claims" => claims
    }

    scope = "implementations"

    {:ok, %{id: job_id}} =
      UploadJobs.create_job(%{
        user_id: claims.user_id,
        hash: hash,
        filename: filename,
        scope: scope
      })

    with :ok <- Bodyguard.permit(Implementations, :mutation, claims, :submit_implementation),
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

  defp search_all_implementations(claims, params) do
    Logger.info("Start searching all implementations")

    Timer.time(
      fn ->
        params
        |> Map.put("without", "deleted_at")
        |> Map.drop(["page", "size"])
        |> Search.scroll_implementations(claims)
      end,
      fn ms, _ -> Logger.info("Searching all implementations in #{ms} ms") end
    )
  end

  defp build_opts(params) do
    {lang, params} = Map.pop(params, "lang", @default_lang)

    params
    |> Map.take(["impl_status", "header_labels"])
    |> Keyword.new(fn
      {"impl_status", "published"} -> {:impl_status, :published}
      {"impl_status", "non_published"} -> {:impl_status, :non_published}
      {key, value} -> {String.to_atom(key), value}
    end)
    |> Keyword.put_new(:header_labels, %{})
    |> Keyword.put(:lang, lang)
  end
end
