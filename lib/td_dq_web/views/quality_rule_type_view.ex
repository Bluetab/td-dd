defmodule TdDqWeb.QualityRuleTypeView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityRuleTypeView

  def render("index.json", %{quality_rule_type: quality_rule_type}) do
    %{data: render_many(quality_rule_type, QualityRuleTypeView, "quality_rule_type.json")}
  end

  def render("show.json", %{quality_rule_type: quality_rule_type}) do
    %{data: render_one(quality_rule_type, QualityRuleTypeView, "quality_rule_type.json")}
  end

  def render("quality_rule_type.json", %{quality_rule_type: quality_rule_type}) do
    %{id: quality_rule_type.id,
      name: quality_rule_type.name,
      params: quality_rule_type.params}
  end
end
