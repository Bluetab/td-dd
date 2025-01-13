defmodule TdDqWeb.ImplementationFilterController do
  use TdDqWeb, :controller

  alias TdDq.Rules.Search

  require Logger

  plug :put_view, TdDqWeb.FilterView

  action_fallback(TdDqWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    params = Map.put(params, "without", "deleted_at")
    {:ok, filters} = Search.get_filter_values(claims, params, :implementations)
    render(conn, "show.json", filters: filters)
  end
end
