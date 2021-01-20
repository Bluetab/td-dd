defmodule TdDdWeb.ProfileController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  require Logger

  alias Plug.Upload
  alias TdDd.CSV.Reader
  alias TdDd.DataStructures.Profile
  alias TdDd.Loader.Worker

  @profiling_import_required Application.compile_env(:td_dd, :profiling)[
                               :profiling_import_required
                             ]
  @profiling_import_schema Application.compile_env(:td_dd, :profiling)[:profiling_import_schema]

  def upload(conn, %{"profiling" => profiling}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, upload(Profile))} do
      do_upload(profiling)
      send_resp(conn, :accepted, "")
    end
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
