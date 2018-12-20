defmodule TdDdWeb.SearchController do
  use TdDdWeb, :controller
  import Canada, only: [can?: 2]
  use PhoenixSwagger
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Search.IndexWorker
  alias TdDdWeb.ErrorView

  swagger_path :reindex_all do
    get("/data_structures/search/reindex_all")
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    user = conn.assigns[:current_user]

    with true <- can?(user, reindex_all(DataStructure)) do
      IndexWorker.reindex()
      send_resp(conn, :accepted, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, "403.json")

      _error ->
        conn
        |> put_status(:internal_server_error)
        |> render(ErrorView, "500.json")
    end
  end
end
