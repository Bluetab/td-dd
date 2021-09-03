defmodule TdDdWeb.SearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Search

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




  swagger_path :search_grants do
    description("Search for grants")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def search_grants(conn, params) do

    IO.puts("SEARCH_GRANTS")
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]
    #manage_permission = can?(claims, manage(%{"resource_type" => "grant"}))
    #user_permissions = %{manage_quality_rules: manage_permission}

    %{
      results: grants,
      aggregations: aggregations,
      total: total
    } =
      params
      |> Map.drop(["page", "size"])
      |> Search.search(claims, page, size)

    #IO.inspect(grants, label: "grants")
    #IO.puts("AQUI**************************************************************")
    IO.inspect(grants, label: "grants search_grants", limit: :infinity)
    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json",
      grants: grants,
      filters: aggregations,
      user_permissions: []
    )
  end













end
