defmodule TdDqWeb.RuleController do
  use TdDqWeb, :controller

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
    manage_permission = Bodyguard.permit?(TdDq.Rules, :manage_quality_rule, claims)
    user_permissions = %{manage_quality_rules: manage_permission}

    rules =
      params
      |> Rules.list_rules(enrich: [:domain])
      |> Enum.filter(&Bodyguard.permit?(Rules, :view, claims, &1))

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
      |> Rules.list_rules(enrich: [:domain], childs: true)
      |> Enum.filter(&Bodyguard.permit?(Rules, :view, claims, &1))

    conn
    |> assign_actions(claims, params)
    |> put_view(RuleView)
    |> render("index.json", rules: rules)
  end

  defp assign_actions(conn, claims, %{"business_concept_id" => id}) do
    {:ok, %{shared_to_ids: shared_to_ids, domain: %{id: domain_id}}} =
      TdCache.ConceptCache.get(id)

    domain_ids = [domain_id | shared_to_ids] |> Enum.uniq()

    domain_ids_with_permission =
      claims
      |> get_domains_with_permission(domain_ids, :manage_quality_rule)
      |> Enum.map(fn d ->
        case TdCache.DomainCache.get(d) do
          {:ok, domain} -> domain
        end
      end)

    if Enum.any?(domain_ids_with_permission) do
      conn
      |> assign(
        :actions,
        %{
          "create" => %{"url" => Routes.rule_path(conn, :create)},
          "domain_ids" => domain_ids_with_permission
        }
      )
    else
      conn
    end
  end

  defp get_domains_with_permission(%{role: "admin"}, domain_ids, _permission), do: domain_ids

  defp get_domains_with_permission(claims, domain_ids, permission) do
    domain_ids
    |> Enum.filter(fn id ->
      TdDq.Permissions.authorized?(claims, permission, id)
    end)
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

    with :ok <- Bodyguard.permit(Rules, :upsert, claims, params),
         {:ok, %{rule: rule}} <- Rules.create_rule(params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.rule_path(conn, :show, rule))
      |> render("show.json", rule: rule, user_permissions: get_user_permissions(claims, rule))
    end
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

    with :ok <- Bodyguard.permit(Rules, :view, claims, rule) do
      render(conn, "show.json", rule: rule, user_permissions: get_user_permissions(claims, rule))
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

    with :ok <- Bodyguard.permit(Rules, :upsert, claims, params),
         {:ok, %{rule: rule}} <- Rules.update_rule(rule, params, claims) do
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

  defp get_user_permissions(claims, %Rule{}) do
    %{manage_quality_rules: Bodyguard.permit?(TdDq.Rules, :manage_quality_rule, claims)}
  end
end
