defmodule TdDdWeb.ProfileController do
  use TdDdWeb, :controller

  alias Jason, as: JSON
  alias Plug.Upload
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.CSV.Reader
  alias TdDd.Loader.LoaderWorker

  require Logger

  action_fallback TdDdWeb.FallbackController

  @profiling_import_required Application.get_env(:td_dd, :profiling)[:profiling_import_required]
  @profiling_import_schema Application.get_env(:td_dd, :profiling)[:profiling_import_schema]

  def upload_profiling(conn, %{"profiling" => profiling}) do
    user = GuardianPlug.current_resource(conn)

    with true <- Map.get(user, :is_admin) do
      do_upload(profiling)
    else
      false ->
          conn
          |> put_status(:forbidden)
          |> put_view(ErrorView)
          |> render("403.json")
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading profiling #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
  end

  defp do_upload(profiling) do
    {:ok, recs} = parse_profiling(profiling)
    load(recs)
  end

  defp parse_profiling(%Upload{path: path}) do
    path
    |> File.stream!()
    |> Reader.read_csv([schema: @profiling_import_schema,
      required: @profiling_import_required])
  end

  defp load(recs) do
    LoaderWorker.load(recs)
  end
end
