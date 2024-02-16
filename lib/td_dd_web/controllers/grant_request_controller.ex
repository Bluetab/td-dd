defmodule TdDdWeb.GrantRequestController do
  use TdDdWeb, :controller

  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.Requests

  action_fallback TdDdWeb.FallbackController

  def index(conn, %{"grant_request_group_id" => id}) do
    claims = conn.assigns[:current_resource]

    with %{requests: requests} = group <- Requests.get_grant_request_group!(id),
         :ok <- Bodyguard.permit(Requests, :view, claims, group) do
      render(conn, "index.json", grant_requests: requests)
    end
  end

  def index(conn, %{"user" => "me"} = params) do
    claims = conn.assigns[:current_resource]

    with {:ok, grant_requests} <-
           Requests.list_grant_requests(
             claims,
             Map.put(params, "user_id_or_created_by_id", claims.user_id)
           ) do
      render(conn, "index.json", grant_requests: grant_requests)
    end
  end

  def index(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Requests, :query, claims, GrantRequest),
         {:ok, grant_requests} <- Requests.list_grant_requests(claims, params) do
      render(conn, "index.json", grant_requests: grant_requests)
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         grant_request <- Requests.get_grant_request!(id, claims),
         :ok <- Bodyguard.permit(Requests, :view, claims, grant_request) do
      render(conn, "show.json", grant_request: grant_request)
    end
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         grant_request <- Requests.get_grant_request!(id, claims),
         :ok <- Bodyguard.permit(Requests, :delete, claims, grant_request),
         {:ok, %GrantRequest{}} <- Requests.delete_grant_request(grant_request) do
      send_resp(conn, :no_content, "")
    end
  end
end
