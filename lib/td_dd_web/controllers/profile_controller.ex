defmodule TdDdWeb.ProfileController do
  use TdDdWeb, :controller

  alias Jason, as: JSON
  alias Plug.Upload
  alias TdDd.CSV.Reader
  alias TdDd.Loader.Worker

  require Logger

  @profiling_import_required Application.compile_env(:td_dd, :profiling)[
                               :profiling_import_required
                             ]
  @profiling_import_schema Application.compile_env(:td_dd, :profiling)[:profiling_import_schema]

  def upload(conn, %{"profiling" => profiling}) do
    %{is_admin: is_admin} = conn.assigns[:current_resource]

    if is_admin do
      do_upload(profiling)
      send_resp(conn, :accepted, "")
    else
      render_error(conn, :forbidden)
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
    |> Reader.read_csv(
      schema: @profiling_import_schema,
      required: @profiling_import_required
    )
  end

  defp load(recs) do
    Worker.load(recs)
  end
end
