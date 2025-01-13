defmodule TdCxWeb.JobFilterController do
  require Logger
  use TdCxWeb, :controller

  alias TdCx.Jobs.Search

  action_fallback(TdCxWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    {:ok, filters} = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end
end
