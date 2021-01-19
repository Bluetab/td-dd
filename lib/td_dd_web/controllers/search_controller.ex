defmodule TdDdWeb.SearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Search
  alias TdDd.Search.Aggregations
  alias TdDd.Utils.CollectionUtils

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

    if can?(claims, reindex_all(DataStructure)) do
      @index_worker.reindex(:all)
      send_resp(conn, :accepted, "")
    else
      render_error(conn, :forbidden)
    end
  end

  def get_source_aliases(conn, _params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    params = Map.put(%{}, :without, ["deleted_at"])

    agg_terms =
      Aggregations.get_agg_terms([
        %{"agg_name" => "source_aliases", "field_name" => "source_alias.raw"}
      ])

    agg_results = Search.get_aggregations_values(claims, permission, params, agg_terms)
    source_aliases = Enum.map(agg_results, &Map.get(&1, "key"))
    body = Jason.encode!(%{data: source_aliases})
    send_resp(conn, :ok, body)
  end

  def get_structures_metadata_types(conn, _params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    params = Map.put(%{}, :without, ["deleted_at"])

    agg_terms =
      Aggregations.get_agg_terms([
        %{"agg_name" => "metadata_type", "field_name" => "type.raw"}
      ])

    agg_results = Search.get_aggregations_values(claims, permission, params, agg_terms)
    metadata_types = Enum.map(agg_results, &Map.get(&1, "key"))
    body = Jason.encode!(%{data: metadata_types})
    send_resp(conn, :ok, body)
  end

  def search_structures_metadata_fields(conn, params) do
    %{role: role} = conn.assigns[:current_resource]

    with {:can, true} <- {:can, role == "admin"} do
      metadata_fields =
        params
        |> Map.get("filters", %{})
        |> CollectionUtils.atomize_keys()
        |> DataStructures.get_structures_metadata_fields()

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, Jason.encode!(%{data: metadata_fields}))
    end
  end
end
