defmodule TdCxWeb.SearchController do
  use TdCxWeb, :controller

  alias TdCx.Jobs
  alias TdCx.Search.Indexer

  action_fallback(TdCxWeb.FallbackController)

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Jobs, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end
end
