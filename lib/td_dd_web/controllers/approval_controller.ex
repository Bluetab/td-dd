defmodule TdDdWeb.ApprovalController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Grants

  action_fallback TdDdWeb.FallbackController

  def create(conn, %{"grant_request_id" => id, "approval" => params}) do
    with claims <- conn.assigns[:current_resource],
         request <- Grants.get_grant_request!(id),
         {:can, true} <- {:can, can?(claims, approve(request))},
         {:ok, %{approval: approval}} <- Grants.create_approval(claims, request, params) do
      conn
      |> put_status(:created)
      # |> put_resp_header("location", Routes.grant_request_approval_path(conn, :show, approval))
      |> render("show.json", approval: approval)
    end
  end
end