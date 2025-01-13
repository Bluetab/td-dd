defmodule TdDdWeb.SystemController do
  use TdDdWeb, :controller

  alias TdDd.Systems
  alias TdDd.Systems.System
  alias TdDd.Systems.SystemSearch

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    params = deleted(params)
    systems = SystemSearch.search_systems(claims, permission, params)
    render(conn, "index.json", systems: systems)
  end

  def create(conn, %{"system" => params}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Systems, :create, claims, System),
         {:ok, %{system: system}} <- Systems.create_system(params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.system_path(conn, :show, system))
      |> render("show.json", system: system)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, system} <- Systems.get_system(id) do
      render(conn, "show.json", system: system)
    end
  end

  def update(conn, %{"id" => id, "system" => params}) do
    with claims <- conn.assigns[:current_resource],
         {:ok, system} <- Systems.get_system(id),
         :ok <- Bodyguard.permit(Systems, :update, claims, system),
         {:ok, %{system: updated_system}} <- Systems.update_system(system, params, claims) do
      render(conn, "show.json", system: updated_system)
    end
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         {:ok, system} <- Systems.get_system(id),
         :ok <- Bodyguard.permit(Systems, :delete, claims, system),
         {:ok, %{system: _deleted_system}} <- Systems.delete_system(system, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  defp deleted(%{"all" => "true"}), do: %{}
  defp deleted(%{"all" => true}), do: %{}
  defp deleted(_params), do: %{"without" => "deleted_at"}
end
