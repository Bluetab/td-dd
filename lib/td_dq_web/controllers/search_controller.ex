defmodule TdDqWeb.SearchController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Rules.Search

  plug :put_view, TdDqWeb.SearchView

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  swagger_path :reindex_all_rules do
    description("Reindex rule index with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all_rules(conn, _params) do
    @index_worker.reindex_rules(:all)
    send_resp(conn, :accepted, "")
  end

  swagger_path :reindex_all_implementations do
    description("Reindex implementation index with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all_implementations(conn, _params) do
    @index_worker.reindex_implementations(:all)
    send_resp(conn, :accepted, "")
  end

  swagger_path :search_rules do
    description("Search for rules")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def search_rules(conn, params) do
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]

    %{
      results: rules,
      aggregations: aggregations,
      total: total
    } =
      params
      |> Map.drop(["page", "size"])
      |> Search.search(claims, page, size)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json",
      rules: rules,
      filters: aggregations,
      user_permissions: %{
        manage_quality_rules: can?(claims, manage(Rule))
      }
    )
  end
end
