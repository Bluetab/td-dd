defmodule TdCxWeb.SearchController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  alias TdCx.Jobs
  alias TdCx.Search.Indexer

  action_fallback(TdCxWeb.FallbackController)

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(202, "Accepted")
    response(403, "Unauthorized")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Jobs, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end
end
