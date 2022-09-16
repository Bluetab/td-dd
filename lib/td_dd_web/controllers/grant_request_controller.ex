defmodule TdDdWeb.GrantRequestController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.Requests

  action_fallback TdDdWeb.FallbackController

  def index(conn, %{"grant_request_group_id" => id}) do
    with claims <- conn.assigns[:current_resource],
         %{requests: requests} = group <- Requests.get_grant_request_group!(id),
         {:can, true} <- {:can, can?(claims, show(group))} do
      render(conn, "index.json", grant_requests: requests)
    end
  end

  def index(conn, %{"user" => "me"} = params) do
    with claims <- conn.assigns[:current_resource],
         {:ok, grant_requests} <-
           Requests.list_grant_requests(
             claims,
             Map.put(params, "user_id_or_created_by_id", claims.user_id)
           ) do
      render(conn, "index.json", grant_requests: grant_requests)
    end
  end

  def index(conn, %{} = params) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, list(GrantRequest))},
         {:ok, grant_requests} <- Requests.list_grant_requests(claims, params) do
      render(conn, "index.json", grant_requests: grant_requests)
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         grant_request <- Requests.get_grant_request!(id, claims),
         {:can, true} <- {:can, can?(claims, show(grant_request))} do
      render(conn, "show.json", grant_request: grant_request)
    end
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         grant_request <- Requests.get_grant_request!(id, claims),
         {:can, true} <- {:can, can?(claims, delete(GrantRequest))},
         {:ok, %GrantRequest{}} <- Requests.delete_grant_request(grant_request) do
      send_resp(conn, :no_content, "")
    end
  end
end
