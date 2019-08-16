defmodule TdDqWeb.SearchController do
  use TdDqWeb, :controller

  use PhoenixSwagger
  import Canada, only: [can?: 2]
  alias TdDq.Accounts.User
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
    user = conn.assigns[:current_resource]

    %{
      results: rules,
      aggregations: aggregations,
      total: total
    } =
      params
      |> Map.drop(["page", "size"])
      |> Search.search(user, page, size)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json",
      rules: rules,
      filters: aggregations,
      user_permissions: get_user_permissions(user, rules)
    )
  end

  defp get_user_permissions(%User{is_admin: true}, _rules),
    do: %{manage_quality_rules: true, execute_quality_rules: true}

  defp get_user_permissions(user, rules) do
    manage_permission = can?(user, manage(%{"resource_type" => "rule"}))

    execute_permission =
      rules
      |> Enum.filter(&can_execute_and_view(user, &1))
      |> Enum.empty?()
      |> Kernel.!()

    %{manage_quality_rules: manage_permission, execute_quality_rules: execute_permission}
  end

  defp can_execute_and_view(user, rule) do
    can?(
      user,
      execute(%{"business_concept_id" => rule.business_concept_id, "resource_type" => "rule"})
    ) &&
      can?(user, show(Rules.get_rule!(rule.id)))
  end
end
