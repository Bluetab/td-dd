defmodule TdDdWeb.GrantFilterController do
  use TdDdWeb, :controller

  alias TdDd.Grants.Search

  require Logger

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    params = Map.put(params, "without", "deleted_at")
    {:ok, filters} = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end

  def search_mine(conn, params) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]
    params = Map.put(params, "without", "deleted_at")
    {:ok, filters} = Search.get_filter_values(claims, params, user_id)
    render(conn, "show.json", filters: filters)
  end
end
