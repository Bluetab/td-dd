defmodule TdDqWeb.QualityRuleController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDq.QualityRules
  alias TdDq.QualityRules.QualityRule
  alias TdDqWeb.SwaggerDefinitions
  alias TdDq.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDqWeb.ErrorView

  action_fallback TdDqWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.quality_rule_definitions()
  end

  swagger_path :index do
    get "/quality_rules"
    description "List Quality Rules"
    response 200, "OK", Schema.ref(:QualityRulesResponse)
  end

  def index(conn, _params) do
    user = get_current_user(conn)
    with true <- can?(user, index(QualityRule)) do
      quality_rules = QualityRules.list_quality_rules()
      render(conn, "index.json", quality_rules: quality_rules)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :create do
    post "/quality_rules"
    description "Creates a Quality Rule"
    produces "application/json"
    parameters do
      quality_rule :body, Schema.ref(:QualityRuleCreate), "Quality Rule create attrs"
    end
    response 201, "Created", Schema.ref(:QualityRuleResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"quality_rule" => quality_rule_params}) do
    user = get_current_user(conn)
    with true <- can?(user, create(QualityRule)),
         {:ok, %QualityRule{} = quality_rule} <- QualityRules.create_quality_rule(quality_rule_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", quality_rule_path(conn, :show, quality_rule))
      |> render("show.json", quality_rule: quality_rule)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :show do
    get "/quality_rules/{id}"
    description "Show Quality Rule"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Rule ID", required: true
    end
    response 200, "OK", Schema.ref(:QualityRuleResponse)
    response 400, "Client Error"
  end

  def show(conn, %{"id" => id}) do
    quality_rule = QualityRules.get_quality_rule!(id)
    user = get_current_user(conn)
    with true <- can?(user, show(quality_rule)) do
      render(conn, "show.json", quality_rule: quality_rule)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :update do
    put "/quality_rules/{id}"
    description "Updates Quality Rule"
    produces "application/json"
    parameters do
      quality_control :body, Schema.ref(:QualityRuleUpdate), "Quality Rule update attrs"
      id :path, :integer, "Quality Rule ID", required: true
    end
    response 200, "OK", Schema.ref(:QualityRuleResponse)
    response 400, "Client Error"
  end

  def update(conn, %{"id" => id, "quality_rule" => quality_rule_params}) do
    quality_rule = QualityRules.get_quality_rule!(id)
    user = get_current_user(conn)
    with true <- can?(user, update(quality_rule)),
         {:ok, %QualityRule{} = quality_rule} <- QualityRules.update_quality_rule(quality_rule, quality_rule_params) do
      render(conn, "show.json", quality_rule: quality_rule)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :delete do
    delete "/quality_rules/{id}"
    description "Delete Quality Rule"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Rule ID", required: true
    end
    response 204, "No Content"
    response 400, "Client Error"
  end

  def delete(conn, %{"id" => id}) do
    quality_rule = QualityRules.get_quality_rule!(id)
    user = get_current_user(conn)
    with true <- can?(user, delete(quality_rule)),
         {:ok, %QualityRule{}} <- QualityRules.delete_quality_rule(quality_rule) do
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp get_current_user(conn) do
    GuardianPlug.current_resource(conn)
  end
end
