defmodule TdDqWeb.RuleFilterController do
  use TdDqWeb, :controller

  alias TdDq.Rules.Search

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  plug :put_view, TdDqWeb.FilterView

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    {:ok, filters} = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end
end
