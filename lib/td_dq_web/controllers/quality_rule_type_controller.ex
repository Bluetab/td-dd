defmodule TdDqWeb.QualityRuleTypeController do
  use TdDqWeb, :controller

  alias TdDq.QualityRules
  alias TdDq.QualityRules.QualityRuleType

  action_fallback TdDqWeb.FallbackController

  def index(conn, _params) do
    quality_rule_type = QualityRules.list_quality_rule_type()
    render(conn, "index.json", quality_rule_type: quality_rule_type)
  end

  def create(conn, %{"quality_rule_type" => quality_rule_type_params}) do
    with {:ok, %QualityRuleType{} = quality_rule_type} <- QualityRules.create_quality_rule_type(quality_rule_type_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", quality_rule_type_path(conn, :show, quality_rule_type))
      |> render("show.json", quality_rule_type: quality_rule_type)
    end
  end

  def show(conn, %{"id" => id}) do
    quality_rule_type = QualityRules.get_quality_rule_type!(id)
    render(conn, "show.json", quality_rule_type: quality_rule_type)
  end

  def update(conn, %{"id" => id, "quality_rule_type" => quality_rule_type_params}) do
    quality_rule_type = QualityRules.get_quality_rule_type!(id)

    with {:ok, %QualityRuleType{} = quality_rule_type} <- QualityRules.update_quality_rule_type(quality_rule_type, quality_rule_type_params) do
      render(conn, "show.json", quality_rule_type: quality_rule_type)
    end
  end

  def delete(conn, %{"id" => id}) do
    quality_rule_type = QualityRules.get_quality_rule_type!(id)
    with {:ok, %QualityRuleType{}} <- QualityRules.delete_quality_rule_type(quality_rule_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
