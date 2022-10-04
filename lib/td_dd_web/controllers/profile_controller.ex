defmodule TdDdWeb.ProfileController do
  use TdDdWeb, :controller

  require Logger

  alias Plug.Upload
  alias TdDd.CSV.Reader
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Loader.Worker
  alias TdDd.Profiles

  action_fallback TdDdWeb.FallbackController

  @profiling_import_required Application.compile_env(:td_dd, :profiling)[
                               :profiling_import_required
                             ]
  @profiling_import_schema Application.compile_env(:td_dd, :profiling)[:profiling_import_schema]

  def search(conn, params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Profiles, :search, claims) do
      profiles = Profiles.list_profiles(params)
      render(conn, "index.json", profiles: profiles)
    end
  end

  def create(conn, %{"data_structure_id" => data_structure_id, "profile" => profile}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Profiles, :create, claims),
         %DataStructure{id: id} <- DataStructures.get_data_structure!(data_structure_id),
         {:ok, profile} <-
           Profiles.create_or_update_profile(%{data_structure_id: id, value: profile}) do
      conn
      |> put_status(:created)
      |> render("show.json", profile: profile)
    end
  end

  def upload(conn, %{"profiling" => profiling}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Profiles, :create, claims) do
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
