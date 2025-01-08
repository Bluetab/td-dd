defmodule TdDdWeb.SearchController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures
  alias TdDd.DataStructures.Search.Indexer

  action_fallback(TdDdWeb.FallbackController)

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructures, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end
end
