defmodule TdDdWeb.SystemController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures
  alias TdDd.DataStructures.System

  action_fallback TdDdWeb.FallbackController

  def index(conn, _params) do
    systems = DataStructures.list_systems()
    render(conn, "index.json", systems: systems)
  end

  def create(conn, %{"system" => system_params}) do
    with {:ok, %System{} = system} <- DataStructures.create_system(system_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.system_path(conn, :show, system))
      |> render("show.json", system: system)
    end
  end

  def show(conn, %{"id" => id}) do
    system = DataStructures.get_system!(id)
    render(conn, "show.json", system: system)
  end

  def update(conn, %{"id" => id, "system" => system_params}) do
    system = DataStructures.get_system!(id)

    with {:ok, %System{} = system} <- DataStructures.update_system(system, system_params) do
      render(conn, "show.json", system: system)
    end
  end

  def delete(conn, %{"id" => id}) do
    system = DataStructures.get_system!(id)

    with {:ok, %System{}} <- DataStructures.delete_system(system) do
      send_resp(conn, :no_content, "")
    end
  end
end
