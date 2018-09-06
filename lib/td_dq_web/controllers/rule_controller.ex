defmodule TdDqWeb.RuleController do
  use TdHypermedia, :controller
  use TdDqWeb, :controller
  use PhoenixSwagger
  import Canada, only: [can?: 2]
  alias TdDq.Audit
  alias TdDq.Rules
  alias TdDq.Rules.Rule
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

  def index(conn, _params) do
      rules = Rules.list_rules()
      render(conn, "index.json", rules: rules)
  end

  swagger_path :get_rules_by_concept do
    description("List Rules of a Business Concept")

    parameters do
      id(:path, :string, "Business Concept ID", required: true)
    end

    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def get_rules_by_concept(conn, %{"id" => id}) do
    user = conn.assigns[:current_resource]
    resource_type = %{
      "business_concept_id" => id,
      "resource_type" => "quality_control"
    }

    with true <- can?(user, get_rules_by_concept(resource_type)) do
      rules = Rules.list_concept_rules(id)

      render(
        conn,
        RuleView,
        "index.json",
        hypermedia: collection_hypermedia("quality_control", conn, rules, resource_type),
        rules: rules
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :create do
    description("Creates a Rule")
    produces("application/json")

    parameters do
      quality_control(:body, Schema.ref(:RuleCreate), "Rule create attrs")
    end

    response(201, "Created", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"quality_control" => quality_control_params}) do
    user = conn.assigns[:current_resource]
    quality_control_params =
      if user do
        Map.put_new(quality_control_params, "updated_by", user.id)
      else
        quality_control_params
      end

    resource_type = quality_control_params
      |> Map.take(["business_concept_id"])
      |> Map.put("resource_type", "quality_control")

    with true <- can?(user, create(resource_type)),
      {:ok, %Rule{} = quality_control} <-
           Rules.create_rule(quality_control_params) do

      audit = %{
        "audit" => %{
          "resource_id" => quality_control.id,
          "resource_type" => "quality_control",
          "payload" => quality_control_params
        }
      }

      Audit.create_event(conn, audit, @events.create_rule)

      conn
        |> put_status(:created)
        |> put_resp_header("location", rule_path(conn, :show, quality_control))
        |> render("show.json", rule: quality_control)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
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
    quality_control = Rules.get_rule!(id)
    render(conn, "show.json", rule: quality_control)
  end

  swagger_path :update do
    description("Updates Rule")
    produces("application/json")

    parameters do
      quality_control(:body, Schema.ref(:RuleUpdate), "Rule update attrs")
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "quality_control" => quality_control_params}) do
    user = conn.assigns[:current_resource]
    quality_control = Rules.get_rule!(id)
    resource_type = %{
      "business_concept_id" => quality_control.business_concept_id,
      "resource_type" => "quality_control"
    }

    quality_control_params =
      if user do
        Map.put_new(quality_control_params, "updated_by", user.id)
      else
        quality_control_params
      end

    with true <- can?(user, update(resource_type)),
            {:ok, %Rule{} = quality_control} <-
              Rules.update_rule(quality_control, quality_control_params) do

      render(conn, "show.json", rule: quality_control)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
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
    quality_control = Rules.get_rule!(id)
    resource_type = %{
      "business_concept_id" => quality_control.business_concept_id,
      "resource_type" => "quality_control"
    }

    with true <- can?(user, delete(resource_type)),
      {:ok, %Rule{}} <- Rules.delete_rule(quality_control) do

      quality_control_params = quality_control
          |> Map.from_struct
          |> Map.delete(:__meta__)

      audit = %{
        "audit" => %{
          "resource_id" => quality_control.id,
          "resource_type" => "quality_control",
          "payload" => quality_control_params
        }
      }

      Audit.create_event(conn, audit, @events.delete_rule)
      send_resp(conn, :no_content, "")

    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
    end
  end
end
