defmodule TdDdWeb.GrantRequestApprovalController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Grants.Requests

  action_fallback TdDdWeb.FallbackController

  def create(conn, %{"grant_request_id" => id, "approval" => params}) do
    with claims <- conn.assigns[:current_resource],
         request <- Requests.get_grant_request!(id),
         {:can, true} <- {:can, can?(claims, approve(request))},
         {:ok, %{approval: approval}} <- Requests.create_approval(claims, request, params) do
      conn
      |> put_status(:created)
      # |> put_resp_header("location", Routes.grant_request_approval_path(conn, :show, approval))
      |> render("show.json", grant_request_approval: approval)
    end
  end
end
