defmodule TdDdWeb.GroupController do
  use TdDdWeb, :controller

  alias TdDd.Groups
  alias TdDd.Systems

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, %{"system_id" => system_external_id}) do
    claims = conn.assigns[:current_resource]

    with system when not is_nil(system) <- Systems.get_by(external_id: system_external_id),
         :ok <- Bodyguard.permit(Systems, :manage, claims, system) do
      groups = Groups.list_by_system(system_external_id)

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, Jason.encode!(%{data: groups}))
    else
      {:error, error} -> {:error, error}
      nil -> {:error, :not_found}
    end
  end

  def delete(conn, %{"system_id" => system_external_id, "id" => group}) do
    claims = conn.assigns[:current_resource]

    with system when not is_nil(system) <- Systems.get_by(external_id: system_external_id),
         :ok <- Bodyguard.permit(Systems, :manage, claims, system),
         :ok <- Groups.delete(system_external_id, group) do
      send_resp(conn, :no_content, "")
    else
      {:error, error} -> {:error, error}
      nil -> {:error, :not_found}
    end
  end
end
