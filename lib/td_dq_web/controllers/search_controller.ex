defmodule TdDqWeb.SearchController do
  use TdDqWeb, :controller

  use PhoenixSwagger
  import Canada, only: [can?: 2]
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDq.Rules.Search
  alias TdDq.Search.IndexWorker

  plug :put_view, TdDqWeb.RuleView

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    rules = Rules.list_all_rules()
    index_name = Rule.index_name()
    IndexWorker.reindex(index_name, rules)
    send_resp(conn, :accepted, "")
  end

  swagger_path :search do
    description("Search for rules")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def search(conn, params) do
    page = params |> Map.get("page", 0)
    size = params |> Map.get("size", 20)

    %{
      results: rules,
      aggregations: aggregations,
      total: total
    } = params
      |> Map.drop(["page", "size"])
      |> Search.search(page, size)

    user = conn.assigns[:current_resource]
    manage_permission = can?(user, manage(%{"resource_type" => "rule"}))
    user_permissions = %{manage_quality_rules: manage_permission}

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json",
      rules: rules,
      filters: aggregations,
      user_permissions: user_permissions
    )
  end
end
