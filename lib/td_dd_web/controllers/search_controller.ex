defmodule TdDdWeb.SearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias Jason, as: JSON

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Search
  alias TdDd.Search.Aggregations

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

  def get_source_aliases(conn, _params) do
    user = conn.assigns[:current_user]
    permission = conn.assigns[:search_permission]
    params = Map.put(%{}, :without, ["deleted_at"])
    agg_terms =
      Aggregations.get_agg_terms([
        %{"agg_name" => "source_aliases", "field_name" => "source_alias.raw"}])
    agg_results = Search.get_aggregations_values(user, permission, params, agg_terms)
    source_aliases = Enum.map(agg_results, &(Map.get(&1, "key")))
    body = JSON.encode!(%{data: source_aliases})
    send_resp(conn, :ok, body)
  end
end
