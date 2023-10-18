defmodule TdDdWeb.GrantRequestBulkApprovalController do
  use TdDdWeb, :controller

  alias TdDd.GrantRequests.Search
  alias TdDd.Grants.Requests
  alias Truedat.Auth.Claims

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, params) do
    search_params =
      params
      |> Map.drop(["role", "comment", "is_rejection"])
      |> maybe_fix_approved_params()

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

  defp maybe_fix_approved_params(
         %{"must" => %{"must_not_approved_by" => approved_by} = filters} = params
       ) do
    must_without_approved = Map.delete(filters, "must_not_approved_by")

    params
    |> Map.put("must", must_without_approved)
    |> Map.put("must_not", %{"approved_by" => approved_by})
  end

  defp maybe_fix_approved_params(params), do: params
end
