defmodule TdDdWeb.GrantRequestFilterController do
  use TdDdWeb, :controller

  alias TdDd.GrantRequests.Search

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]

    params = Search.apply_approve_filters(params)

    {:ok, filters} = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end
end
