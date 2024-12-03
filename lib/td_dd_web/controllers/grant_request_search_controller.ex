defmodule TdDdWeb.GrantRequestSearchController do
  use TdDdWeb, :controller

  alias TdDd.GrantRequests.Search
  alias TdDd.GrantRequests.Search.Indexer
  alias Truedat.Search.Permissions
  @default_page 0
  @default_size 20

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    %{total: total} =
      response =
      params
      |> Search.apply_approve_filters()
      |> Search.search(claims, page, size)
      |> put_permissions(claims)

    assigns =
      response
      |> get_assigns()
      |> maybe_put_filters(response)
      |> maybe_put_scroll_id(response)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", assigns)
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Grants, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end

  defp get_assigns(%{results: grant_requests, permissions: permissions}) do
    [grant_request: grant_requests, permissions: permissions]
  end

  defp maybe_put_filters(assigns, %{aggregations: aggregations}),
    do: Keyword.put(assigns, :filters, aggregations)

  defp maybe_put_filters(assigns, _), do: assigns

  defp maybe_put_scroll_id(assigns, %{scroll_id: scroll_id}),
    do: Keyword.put(assigns, :scroll_id, scroll_id)

  defp maybe_put_scroll_id(assigns, _), do: assigns

  defp put_permissions(response, claims) do
    permissions = Permissions.get_roles_by_user(:approve_grant_request, claims)
    Map.put(response, :permissions, permissions)
  end
end
