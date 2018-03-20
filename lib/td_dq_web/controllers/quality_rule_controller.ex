defmodule TdDqWeb.QualityRuleController do
  use TdDqWeb, :controller

  alias TdDq.QualityRules
  alias TdDq.QualityRules.QualityRule

  action_fallback TdDqWeb.FallbackController

  def index(conn, _params) do
    quality_rules = QualityRules.list_quality_rules()
    render(conn, "index.json", quality_rules: quality_rules)
  end

  def create(conn, %{"quality_rule" => quality_rule_params}) do
    with {:ok, %QualityRule{} = quality_rule} <- QualityRules.create_quality_rule(quality_rule_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", quality_rule_path(conn, :show, quality_rule))
      |> render("show.json", quality_rule: quality_rule)
    end
  end

  def show(conn, %{"id" => id}) do
    quality_rule = QualityRules.get_quality_rule!(id)
    render(conn, "show.json", quality_rule: quality_rule)
  end

  def update(conn, %{"id" => id, "quality_rule" => quality_rule_params}) do
    quality_rule = QualityRules.get_quality_rule!(id)

    with {:ok, %QualityRule{} = quality_rule} <- QualityRules.update_quality_rule(quality_rule, quality_rule_params) do
      render(conn, "show.json", quality_rule: quality_rule)
    end
  end

  def delete(conn, %{"id" => id}) do
    quality_rule = QualityRules.get_quality_rule!(id)
    with {:ok, %QualityRule{}} <- QualityRules.delete_quality_rule(quality_rule) do
      send_resp(conn, :no_content, "")
    end
  end
end
