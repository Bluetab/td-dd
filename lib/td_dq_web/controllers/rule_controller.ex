defmodule TdDqWeb.RuleController do
  use TdHypermedia, :controller
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Implementations.Implementation
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDqWeb.RuleView

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.rule_definitions()
  end

  swagger_path :index do
    description("List Rules")
    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]
    manage_permission = can?(claims, manage(Rule))
    user_permissions = %{manage_quality_rules: manage_permission}

    rules =
      params
      |> Rules.list_rules(enrich: [:domain])
      |> Enum.filter(&can?(claims, show(&1)))

    render(conn, "index.json",
      rules: rules,
      user_permissions: user_permissions
    )
  end

  swagger_path :get_rules_by_concept do
    description("List Rules of a Business Concept")

    parameters do
      business_concept_id(:path, :string, "Business Concept ID", required: true)
    end

    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def get_rules_by_concept(conn, %{"business_concept_id" => _id} = params) do
    claims = conn.assigns[:current_resource]

    rules =
      params
      |> Rules.list_rules(enrich: [:domain])
      |> Enum.filter(&can?(claims, show(&1)))

    conn
    |> assign_actions(claims)
    |> put_view(RuleView)
    |> render("index.json", rules: rules)
  end

  defp assign_actions(conn, claims) do
    if can?(claims, manage(Rule)) do
      assign(conn, :actions, %{"create" => Routes.rule_path(conn, :create)})
    else
      conn
    end
  end

  swagger_path :create do
    description("Creates a Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleCreate), "Rule creation parameters")
    end

    response(201, "Created", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule" => params}) do
    claims = conn.assigns[:current_resource]

    with {:ok, %{rule: rule}} <- Rules.create_rule(params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.rule_path(conn, :show, rule))
      |> render("show.json", rule: rule, user_permissions: get_user_permissions(claims, rule))
    end
  end

  defp get_user_permissions(claims, rule) do
    %{
      manage_quality_rules: can?(claims, manage(Rule)),
      manage_quality_rule_implementations: can?(claims, manage(%Implementation{rule: rule})),
      manage_raw_quality_rule_implementations:
        can?(claims, manage(%Implementation{rule: rule, implementation_type: "raw"}))
    }
  end

  swagger_path :show do
    description("Show Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id, enrich: [:domain])

    with {:can, true} <- {:can, can?(claims, show(rule))} do
      render(
        conn,
        "show.json",
        hypermedia: hypermedia("rule", conn, rule),
        rule: rule,
        user_permissions: get_user_permissions(claims, rule)
      )
    end
  end

  swagger_path :update do
    description("Updates Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleUpdate), "Rule update parameters")
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule" => params}) do
    claims = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    with {:ok, %{rule: rule}} <- Rules.update_rule(rule, params, claims) do
      render(conn, "show.json", rule: rule, user_permissions: get_user_permissions(claims, rule))
    end
  end

  swagger_path :delete do
    description("Delete Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    with {:ok, _res} <- Rules.delete_rule(rule, claims) do
      send_resp(conn, :no_content, "")
    end
  end
end
