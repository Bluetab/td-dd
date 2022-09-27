defmodule TdDqWeb.RuleSearchController do
  use TdDqWeb, :controller

  alias TdDq.Rules
  alias TdDq.Rules.Search

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  swagger_path :reindex do
    description("Reindex rule index with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Rules, :reindex, claims) do
      @index_worker.reindex_rules(:all)
      send_resp(conn, :accepted, "")
    end
  end

  swagger_path :create do
    description("Search for rules")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def create(conn, params) do
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]

    %{
      results: rules,
      total: total
    } =
      params
      |> Map.drop(["page", "size"])
      |> Search.search_rules(claims, page, size)

    conn
    |> put_view(TdDqWeb.SearchView)
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json",
      rules: rules,
      filters: %{},
      user_permissions: %{
        manage_quality_rules: Bodyguard.permit?(Rules, :manage_quality_rule, claims)
      }
    )
  end
end
