defmodule TdDdWeb.GrantRequestController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Grants
  alias TdDd.Grants.GrantRequest

  action_fallback TdDdWeb.FallbackController

  def index(conn, %{"grant_request_group_id" => id}) do
    with claims <- conn.assigns[:current_resource],
         %{requests: requests} = group <- Grants.get_grant_request_group!(id),
         {:can, true} <- {:can, can?(claims, show(group))} do
      render(conn, "index.json", grant_requests: requests)
    end
  end

  def index(conn, %{} = params) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, list(GrantRequest))},
         {:ok, grant_requests} <- Grants.list_grant_requests(claims, params) do
      render(conn, "index.json", grant_requests: grant_requests)
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, show(GrantRequest))} do
      grant_request = Grants.get_grant_request!(id)
      render(conn, "show.json", grant_request: grant_request)
    end
  end

  def delete(conn, %{"id" => id}) do
    grant_request = Grants.get_grant_request!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, delete(GrantRequest))},
         {:ok, %GrantRequest{}} <- Grants.delete_grant_request(grant_request) do
      send_resp(conn, :no_content, "")
    end
  end
end
