defmodule TdDdWeb.ProfileController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  require Logger

  alias Plug.Upload
  alias TdDd.CSV.Reader
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.Profiles
  alias TdDd.Loader.Worker

  @profiling_import_required Application.compile_env(:td_dd, :profiling)[
                               :profiling_import_required
                             ]
  @profiling_import_schema Application.compile_env(:td_dd, :profiling)[:profiling_import_schema]

  def create(conn, %{"data_structure_id" => data_structure_id, "profile" => profile}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, upload(Profile))},
         %DataStructure{id: id} <-
           DataStructures.get_data_structure_by_external_id(data_structure_id),
         {:ok, profile} <-
           Profiles.create_or_update_profile(%{data_structure_id: id, value: profile}) do
      conn
      |> put_status(:created)
      |> render("show.json", profile: profile)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

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
