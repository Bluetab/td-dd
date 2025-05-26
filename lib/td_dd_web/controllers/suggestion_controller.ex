defmodule TdDdWeb.SuggestionController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures
  alias TdDd.DataStructures.Search.Suggestions
  alias TdDdWeb.DataStructureView

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]

    with :ok <- Bodyguard.permit(DataStructures, :suggest_structures, claims) do
      %{results: data_structures} = Suggestions.knn(claims, permission, params)

      conn
      |> put_view(DataStructureView)
      |> render("index.json", data_structures: data_structures)
    end
  end
end
