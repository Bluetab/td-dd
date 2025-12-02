defmodule TdDqWeb.Implementation.XLSXController do
  use TdDqWeb, :controller

  alias TdCore.Utils.FileHash
  alias TdDq.Implementations
  alias TdDq.Implementations.Search
  alias TdDq.Implementations.UploadEvents
  alias TdDq.XLSX.Download
  alias TdDq.XLSX.Jobs.UploadWorker

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
    path = copy_file(file_path)

    hash = FileHash.hash(path, :md5)

    opts = %{
      "auto_publish" => Map.get(params, "auto_publish"),
      "lang" => lang,
      "claims" => claims
    }

    {:ok, %{id: job_id}} =
      UploadEvents.create_job(%{user_id: claims.user_id, hash: hash, filename: filename})

    with :ok <- Bodyguard.permit(Implementations, :mutation, claims, :submit_implementation),
         {:ok, _} <- UploadEvents.create_pending(job_id) do
      %{path: path, job_id: job_id, opts: opts}
      |> UploadWorker.new()
      |> Oban.insert()

      json(conn, %{job_id: job_id})
    else
      {:error, reason} ->
        UploadEvents.create_failed(job_id, reason)
        {:error, reason}
    end
  end

  def upload_jobs(conn, _params) do
    claims = conn.assigns[:current_resource]

    jobs = UploadEvents.list_jobs(user_id: claims.user_id)
    render(conn, "upload_jobs.json", jobs: jobs)
  end

  def upload_job(conn, %{"job_id" => job_id}) do
    %{user_id: user_id} = conn.assigns[:current_resource]

    case UploadEvents.get_job(job_id) do
      %{user_id: ^user_id} = job ->
        render(conn, "upload_job.json", job: job)

      _ ->
        send_resp(conn, :not_found, "")
    end
  end

  defp search_all_implementations(claims, params) do
    params
    |> Map.put("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> Search.scroll_implementations(claims)
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

  defp copy_file(path) do
    upload_dir = @file_upload_dir
    :ok = File.mkdir_p!(upload_dir)
    source_file_name = path |> Path.split() |> List.last()
    file_path = Path.join([upload_dir, source_file_name])
    :ok = File.cp!(path, file_path)
    file_path
  end
end
