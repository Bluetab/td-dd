defmodule TdDdWeb.GrantSearchController do
  use TdDdWeb, :controller

  alias TdDd.Grants.Search
  alias TdDd.Grants.Search.Indexer

  action_fallback(TdDdWeb.FallbackController)

  def reindex_all_grants(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Grants, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end

  def search_grants(conn, params) do
    %{total: total} = response = search(conn, params, :by_permissions)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", search_assigns(response))
  end

  def search_my_grants(conn, params) do
    %{total: total} = response = search(conn, params, :by_user)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", search_assigns(response))
  end

  defp search(_conn, %{"scroll_id" => _scroll_id, "scroll" => _scroll} = params, _by) do
    Search.scroll_grants(params)
  end

  defp search(conn, params, by) do
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]

    params
    |> Map.put_new("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> search(claims, page, size, by)
  end

  defp search(params, claims, page, size, :by_user) do
    Search.search_by_user(params, claims, page, size)
  end

  defp search(params, claims, page, size, :by_permissions) do
    Search.search(params, claims, page, size)
  end

  defp search_assigns(%{results: grants, scroll_id: scroll_id}) do
    [grants: grants, scroll_id: scroll_id]
  end

  defp search_assigns(%{results: grants, aggregations: aggregations}) do
    [grants: grants, filters: aggregations]
  end

  defp search_assigns(%{results: grants}) do
    [grants: grants]
  end
end
