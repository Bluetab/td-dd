defmodule TdDdWeb.SearchController do
use TdDdWeb, :controller
use PhoenixSwagger

# alias TdDd.Search
alias TdDd.Search.Indexer

# def search(%{body_params: query} = conn, %{"search_id" => index_name}) do
#   resp = Search.search(index_name, query)
#   json conn, %{data: resp}
# end

swagger_path :reindex_all do
  get "/search/reindex_all"
  description "Reindex all ES indexes with DB content"
  produces "application/json"
  response 200, "OK"
  response 500, "Client Error"
end
def reindex_all(conn, _params) do
  {:ok, _response} = Indexer.reindex(:data_structure)
  send_resp(conn, :ok, "")
end

end
