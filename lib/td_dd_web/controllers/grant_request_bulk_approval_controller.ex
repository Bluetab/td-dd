defmodule TdDdWeb.GrantRequestBulkApprovalController do
  use TdDdWeb, :controller

  alias TdDd.GrantRequests.Search
  alias TdDd.Grants.Requests

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, params) do
    search_params =
      params
      |> Map.drop(["role", "comment", "is_rejection"])
      |> Search.apply_approve_filters()

    with claims <- conn.assigns[:current_resource],
         %{results: grant_requests} <- Search.search(search_params, claims),
         bulk_params <- Map.take(params, ["role", "comment", "is_rejection"]),
         {:ok, %{approvals: {_total, approvals}}} <-
           Requests.bulk_create_approvals(claims, grant_requests, bulk_params) do
      conn
      |> put_status(:created)
      |> render("show.json", grant_request_bulk_approval: approvals)
    end
  end
end
