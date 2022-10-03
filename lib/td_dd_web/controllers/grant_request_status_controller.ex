defmodule TdDdWeb.GrantRequestStatusController do
  use TdDdWeb, :controller

  alias TdDd.Grants.Requests
  alias TdDd.Grants.Statuses
  alias TdDdWeb.GrantRequestView

  action_fallback TdDdWeb.FallbackController

  def create(conn, %{"grant_request_id" => id, "status" => "cancelled" = status}) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         request <- Requests.get_grant_request!(id, claims),
         :ok <- Bodyguard.permit(Requests, :cancel, claims, request),
         {:ok, _grant_request_status} <-
           Statuses.create_grant_request_status(request, status, user_id),
         updated_request <- Requests.get_grant_request!(id, claims) do
      conn
      |> put_status(:created)
      |> put_view(GrantRequestView)
      |> render("show.json", grant_request: updated_request)
    end
  end

  def create(conn, %{"grant_request_id" => id, "status" => status} = params) do
    status_reason = Map.get(params, "reason")

    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         request <- Requests.get_grant_request!(id, claims),
         :ok <- Bodyguard.permit(Requests, :approve, claims, request),
         {:ok, _grant_request_status} <-
           Statuses.create_grant_request_status(request, status, user_id, status_reason),
         updated_request <- Requests.get_grant_request!(id, claims) do
      conn
      |> put_status(:created)
      |> put_view(GrantRequestView)
      |> render("show.json", grant_request: updated_request)
    end
  end
end
