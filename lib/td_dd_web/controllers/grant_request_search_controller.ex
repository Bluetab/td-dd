defmodule TdDdWeb.GrantRequestSearchController do
  use TdDdWeb, :controller

  alias TdCore.Search.IndexWorker
  alias TdDd.GrantRequests.Search
  alias Truedat.Search.Permissions

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]

    %{total: total} =
      response =
      params
      |> maybe_fix_approved_params()
      |> Search.search(claims)
      |> put_permissions(claims)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", search_assigns(response))
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Grants, :reindex, claims) do
      IndexWorker.reindex(:grant_requests, :all)
      send_resp(conn, :accepted, "")
    end
  end

  defp search_assigns(%{
         results: grant_requests,
         aggregations: aggregations,
         permissions: permissions
       }) do
    [grant_requests: grant_requests, filters: aggregations, permissions: permissions]
  end

  defp search_assigns(%{results: grant_requests, permissions: permissions}) do
    [grant_request: grant_requests, permissions: permissions]
  end

  defp put_permissions(response, claims) do
    permissions = Permissions.get_roles_by_user(:approve_grant_request, claims)
    Map.put(response, :permissions, permissions)
  end

  defp maybe_fix_approved_params(
         %{"must" => %{"must_not_approved_by" => approved_by} = must} = params
       ) do
    must_without_approved = Map.delete(must, "must_not_approved_by")

    params
    |> Map.put("must", must_without_approved)
    |> Map.put("must_not", %{"approved_by" => approved_by})
  end

  defp maybe_fix_approved_params(params), do: params
end
