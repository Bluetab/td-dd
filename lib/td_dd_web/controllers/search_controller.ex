defmodule TdDdWeb.SearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  alias TdDd.DataStructures

  action_fallback(TdDdWeb.FallbackController)

  @index_worker Application.compile_env(:td_dd, :index_worker)

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructures, :reindex, claims) do
      @index_worker.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end
end
