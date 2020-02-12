defmodule TdDdWeb.SearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures.DataStructure

  @index_worker Application.get_env(:td_dd, :index_worker)

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    user = conn.assigns[:current_user]

    if can?(user, reindex_all(DataStructure)) do
      @index_worker.reindex(:all)
      send_resp(conn, :accepted, "")
    else
      render_error(conn, :forbidden)
    end
  end
end
