defmodule TdDqWeb.RuleTypeController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias TdDq.Rules
  alias TdDq.Rules.RuleType
  alias TdDqWeb.ErrorView
  alias TdDqWeb.SwaggerDefinitions

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.rule_type_definitions()
  end

  swagger_path :index do
    description("List Quality Rule Types")
    response(200, "OK", Schema.ref(:RuleTypesResponse))
  end

  def index(conn, _params) do
    rule_types = Rules.list_rule_types()
    render(conn, "index.json", rule_types: rule_types)
  end

  swagger_path :create do
    description("Creates a Quality Rule Type")
    produces("application/json")

    parameters do
      rule_type(
        :body,
        Schema.ref(:RuleTypeCreate),
        "Quality Rule Type create attrs"
      )
    end

    response(201, "Created", Schema.ref(:RuleTypeResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule_type" => rule_type_params}) do
    with {:ok, %RuleType{} = rule_type} <- Rules.create_rule_type(rule_type_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", rule_type_path(conn, :show, rule_type))
      |> render("show.json", rule_type: rule_type)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :show do
    description("Show Quality Rule Type")
    produces("application/json")

    parameters do
      id(:path, :integer, "Quality Rule Type ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleTypeResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    rule_type = Rules.get_rule_type!(id)
    render(conn, "show.json", rule_type: rule_type)
  end

  swagger_path :update do
    description("Updates Quality Rule Type")
    produces("application/json")

    parameters do
      rule_type(
        :body,
        Schema.ref(:RuleTypeUpdate),
        "Quality Rule Type update attrs"
      )

      id(:path, :integer, "Quality Rule Type ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleTypeResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule_type" => rule_type_params}) do
    rule_type = Rules.get_rule_type!(id)

    with {:ok, %RuleType{} = rule_type} <- Rules.update_rule_type(rule_type, rule_type_params) do
      render(conn, "show.json", rule_type: rule_type)
    end
  end

  swagger_path :delete do
    description("Delete Quality Rule Type")
    produces("application/json")

    parameters do
      id(:path, :integer, "Quality Rule Type ID", required: true)
    end

    response(200, "OK")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    rule_type = Rules.get_rule_type!(id)

    with {:ok, %RuleType{}} <- Rules.delete_rule_type(rule_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
