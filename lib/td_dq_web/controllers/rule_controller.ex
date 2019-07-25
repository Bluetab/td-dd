defmodule TdDqWeb.RuleController do
  require Logger
  use TdHypermedia, :controller
  use TdDqWeb, :controller
  use PhoenixSwagger
  import Canada, only: [can?: 2]
  alias Ecto.Changeset
  alias TdDq.Audit
  alias TdDq.Repo
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDqWeb.ChangesetView
  alias TdDqWeb.ErrorView
  alias TdDqWeb.RuleView
  alias TdDqWeb.SwaggerDefinitions

  action_fallback(TdDqWeb.FallbackController)

  @events %{create_rule: "create_rule", delete_rule: "delete_rule"}

  def swagger_definitions do
    SwaggerDefinitions.rule_definitions()
  end

  swagger_path :index do
    description("List Rules")
    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_resource]
    manage_permission = can?(user, manage(%{"resource_type" => "rule"}))
    user_permissions = %{manage_quality_rules: manage_permission}

    rules =
      params
      |> Rules.list_rules()
      |> Enum.filter(&can?(user, show(&1)))

    render(conn, "index.json",
      rules: rules,
      user_permissions: user_permissions
    )
  end

  swagger_path :get_rules_by_concept do
    description("List Rules of a Business Concept")

    parameters do
      id(:path, :string, "Business Concept ID", required: true)
    end

    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def get_rules_by_concept(conn, %{"id" => id} = params) do
    user = conn.assigns[:current_resource]

    resource_type = %{
      "business_concept_id" => id,
      "resource_type" => "rule"
    }

    with true <- can?(user, get_rules_by_concept(resource_type)) do
      params =
        params
        |> Map.put("business_concept_id", id)
        |> Map.delete("id")

      rules =
        params
        |> Rules.list_concept_rules()
        |> Enum.filter(&can?(user, show(&1)))

      conn
      |> put_view(RuleView)
      |> render(
        "index.json",
        hypermedia: collection_hypermedia("rule", conn, rules, resource_type),
        rules: rules
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :create do
    description("Creates a Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleCreate), "Rule create attrs")
    end

    response(201, "Created", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule" => rule_params}) do
    user = conn.assigns[:current_resource]
    rule_type_id = rule_params["rule_type_id"]
    rule_type = Rules.get_rule_type_or_nil(rule_type_id)

    creation_attrs =
      rule_params
      |> Map.put_new("updated_by", user.id)

    resource_type =
      rule_params
      |> Map.take(["business_concept_id"])
      |> Map.put("resource_type", "rule")

    with true <- can?(user, create(resource_type)),
         {:ok, %Rule{} = rule} <- Rules.create_rule(rule_type, creation_attrs) do
      audit = %{
        "audit" => %{
          "resource_id" => rule.id,
          "resource_type" => "rule",
          "payload" => rule_params
        }
      }

      Audit.create_event(conn, audit, @events.create_rule)

      conn
      |> put_status(:created)
      |> put_resp_header("location", rule_path(conn, :show, rule))
      |> render("show.json", rule: rule, user_permissions: get_user_permissions(conn, rule))
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.type_params.error"
        )

      error ->
        Logger.error("While creating rule... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp get_user_permissions(conn, rule) do
    user = conn.assigns[:current_resource]
    manage_permission = can?(user, manage(%{"resource_type" => "rule"}))

    manage_rule_implementations =
      can?(
        user,
        manage(%{
          "resource_type" => "rule_implementation",
          "business_concept_id" => rule.business_concept_id
        })
      )

    %{
      manage_quality_rules: manage_permission,
      manage_quality_rule_implementations: manage_rule_implementations
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
    user = conn.assigns[:current_resource]

    rule =
      id
      |> Rules.get_rule!()
      |> Repo.preload(:rule_type)

    with true <- can?(user, show(rule)) do
      render(
        conn,
        "show.json",
        hypermedia:
          hypermedia("rule", conn, %{
            "business_concept_id" => rule.business_concept_id,
            "resource_type" => "rule"
          }),
        rule: rule,
        user_permissions: get_user_permissions(conn, rule)
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  end

  swagger_path :get_rule_detail do
    description("Show Rule with details over the data of its relations")
    produces("application/json")

    parameters do
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleDetailResponse))
    response(400, "Client Error")
  end

  def get_rule_detail(conn, %{"rule_id" => id}) do
    user = conn.assigns[:current_resource]
    rule = Rules.get_rule_detail!(id)

    with true <- can?(user, show(rule)) do
      render(
        conn,
        "show.json",
        hypermedia:
          hypermedia("rule", conn, %{
            "business_concept_id" => rule.business_concept_id,
            "resource_type" => "rule"
          }),
        rule: rule
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  end

  swagger_path :update do
    description("Updates Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleUpdate), "Rule update attrs")
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    user = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule"
    }

    update_attrs =
      rule_params
      |> Map.put_new("updated_by", user.id)

    with true <- can?(user, update(resource_type)),
         {:ok, %Rule{} = rule} <- Rules.update_rule(rule, update_attrs) do
      render(conn, "show.json", rule: rule, user_permissions: get_user_permissions(conn, rule))
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.type_params.error"
        )

      error ->
        Logger.error("While updating rule... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
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
    user = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule"
    }

    with true <- can?(user, delete(resource_type)),
         {:ok, %Rule{}} <- Rules.delete_rule(rule) do
      rule_params =
        rule
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> Map.delete(:rule_type)
        |> Map.delete(:rule_implementations)

      audit = %{
        "audit" => %{
          "resource_id" => rule.id,
          "resource_type" => "rule",
          "payload" => rule_params
        }
      }

      Audit.create_event(conn, audit, @events.delete_rule)
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )
    end
  end
end
