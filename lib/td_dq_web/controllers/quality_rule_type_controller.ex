defmodule TdDqWeb.QualityRuleTypeController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias TdDq.QualityRules
  alias TdDq.QualityRules.QualityRuleType
  alias TdDqWeb.SwaggerDefinitions

  action_fallback TdDqWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.quality_rule_type_definitions()
  end

  swagger_path :index do
    get "/quality_rule_types"
    description "List Quality Rule Types"
    response 200, "OK", Schema.ref(:QualityRuleTypesResponse)
  end

  def index(conn, _params) do
    quality_rule_type = QualityRules.list_quality_rule_types()
    render(conn, "index.json", quality_rule_type: quality_rule_type)
  end

  swagger_path :create do
    post "/quality_rule_types"
    description "Creates a Quality Rule Type"
    produces "application/json"
    parameters do
      quality_rule_type :body, Schema.ref(:QualityRuleTypeCreate), "Quality Rule Type create attrs"
    end
    response 201, "Created", Schema.ref(:QualityRuleTypeResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"quality_rule_type" => quality_rule_type_params}) do
    with {:ok, %QualityRuleType{} = quality_rule_type} <- QualityRules.create_quality_rule_type(quality_rule_type_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", quality_rule_type_path(conn, :show, quality_rule_type))
      |> render("show.json", quality_rule_type: quality_rule_type)
    end
  end

  swagger_path :show do
    get "/quality_rule_types/{id}"
    description "Show Quality Rule Type"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Rule Type ID", required: true
    end
    response 200, "OK", Schema.ref(:QualityRuleTypeResponse)
    response 400, "Client Error"
  end

  def show(conn, %{"id" => id}) do
    quality_rule_type = QualityRules.get_quality_rule_type!(id)
    render(conn, "show.json", quality_rule_type: quality_rule_type)
  end

  swagger_path :update do
    put "/quality_rule_types/{id}"
    description "Updates Quality Rule Type"
    produces "application/json"
    parameters do
      quality_rule_type :body, Schema.ref(:QualityRuleTypeUpdate), "Quality Rule Type update attrs"
      id :path, :integer, "Quality Rule Type ID", required: true
    end
    response 200, "OK", Schema.ref(:QualityRuleTypeResponse)
    response 400, "Client Error"
  end

  def update(conn, %{"id" => id, "quality_rule_type" => quality_rule_type_params}) do
    quality_rule_type = QualityRules.get_quality_rule_type!(id)

    with {:ok, %QualityRuleType{} = quality_rule_type} <- QualityRules.update_quality_rule_type(quality_rule_type, quality_rule_type_params) do
      render(conn, "show.json", quality_rule_type: quality_rule_type)
    end
  end

  swagger_path :delete do
    delete "/quality_rule_types/{id}"
    description "Delete Quality Rule Type"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Rule Type ID", required: true
    end
    response 200, "OK"
    response 400, "Client Error"
  end

  def delete(conn, %{"id" => id}) do
    quality_rule_type = QualityRules.get_quality_rule_type!(id)
    with {:ok, %QualityRuleType{}} <- QualityRules.delete_quality_rule_type(quality_rule_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
