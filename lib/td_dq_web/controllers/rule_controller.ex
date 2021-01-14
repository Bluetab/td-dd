defmodule TdDqWeb.RuleController do
  use TdHypermedia, :controller
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias Ecto.Changeset
  alias TdDq.Rules
  alias TdDqWeb.ChangesetView
  alias TdDqWeb.ErrorView
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
    manage_permission = can?(claims, manage(%{"resource_type" => "rule"}))
    user_permissions = %{manage_quality_rules: manage_permission}

    rules =
      params
      |> Rules.list_rules()
      |> Enum.filter(&can?(claims, show(&1)))

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
    claims = conn.assigns[:current_resource]

    resource_type = %{
      "business_concept_id" => id,
      "resource_type" => "rule"
    }

    with {:can, true} <- {:can, can?(claims, get_rules_by_concept(resource_type))} do
      params =
        params
        |> Map.put("business_concept_id", id)
        |> Map.delete("id")

      rules =
        params
        |> Rules.list_concept_rules()
        |> Enum.filter(&can?(claims, show(&1)))

      conn
      |> put_view(RuleView)
      |> render(
        "index.json",
        hypermedia: collection_hypermedia("rule", conn, rules, resource_type),
        rules: rules
      )
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

  def create(conn, %{"rule" => rule_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    params = Map.put_new(rule_params, "updated_by", user_id)

    resource_type =
      rule_params
      |> Map.take(["business_concept_id"])
      |> Map.put("resource_type", "rule")

    with {:can, true} <- {:can, can?(claims, create(resource_type))},
         {:ok, %{rule: rule}} <- Rules.create_rule(params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.rule_path(conn, :show, rule))
      |> render("show.json", rule: rule, user_permissions: get_user_permissions(conn, rule))
    else
      {:can, false} ->
        {:can, false}

      {:error, :rule, %Changeset{data: %{__struct__: _}} = changeset, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )

      {:error, :rule, %Changeset{} = changeset, _} ->
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
    claims = conn.assigns[:current_resource]
    manage_permission = can?(claims, manage(%{"resource_type" => "rule"}))

    manage_rule_implementations =
      can?(
        claims,
        manage(%{
          "resource_type" => "implementation",
          "business_concept_id" => rule.business_concept_id
        })
      )

    manage_raw_rule_implementations =
      can?(
        claims,
        manage_raw(%{
          "resource_type" => "implementation",
          "business_concept_id" => rule.business_concept_id
        })
      )

    %{
      manage_quality_rules: manage_permission,
      manage_quality_rule_implementations: manage_rule_implementations,
      manage_raw_quality_rule_implementations: manage_raw_rule_implementations
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

    rule = Rules.get_rule!(id)

    with {:can, true} <- {:can, can?(claims, show(rule))} do
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

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule"
    }

    params = Map.put_new(rule_params, "updated_by", user_id)

    with {:can, true} <- {:can, can?(claims, update(resource_type))},
         {:ok, %{rule: rule}} <- Rules.update_rule(rule, params, claims) do
      render(conn, "show.json", rule: rule, user_permissions: get_user_permissions(conn, rule))
    else
      {:can, false} ->
        {:can, false}

      {:error, :rule, %Changeset{data: %{__struct__: _}} = changeset, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )

      {:error, :rule, %Changeset{} = changeset, _} ->
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
    claims = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule"
    }

    with {:can, true} <- {:can, can?(claims, delete(resource_type))},
         {:ok, _res} <- Rules.delete_rule(rule, claims) do
      send_resp(conn, :no_content, "")
    else
      {:can, false} ->
        {:can, false}

      {:error, :rule, %Changeset{data: %{__struct__: _}} = changeset, _} ->
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
