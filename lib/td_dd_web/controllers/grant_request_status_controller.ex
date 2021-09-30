defmodule TdDdWeb.GrantRequestStatusController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Grants.Requests
  alias TdDd.Grants.Statuses
  alias TdDdWeb.GrantRequestView

  action_fallback TdDdWeb.FallbackController

  def create(conn, %{"grant_request_id" => id, "status" => status}) do
    with claims <- conn.assigns[:current_resource],
         request <- Requests.get_grant_request!(id),
         {:can, true} <- {:can, can?(claims, approve(request))},
         {:ok, _grant_request_status} <- Statuses.create_grant_request_status(request, status),
         updated_request <- Requests.get_grant_request!(id) do
      conn
      |> put_status(:created)
      |> put_view(GrantRequestView)
      |> render("show.json", grant_request: updated_request)
    end
  end
end
