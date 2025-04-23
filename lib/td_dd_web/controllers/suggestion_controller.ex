defmodule TdDdWeb.SuggestionController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.Search.Suggestions

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    Suggestions.knn(claims, permission, params)
    send_resp(conn, :accepted, "")
  end
end
