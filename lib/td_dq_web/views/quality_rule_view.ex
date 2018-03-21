defmodule TdDqWeb.QualityRuleView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityRuleView

  def render("index.json", %{quality_rules: quality_rules}) do
    %{data: render_many(quality_rules, QualityRuleView, "quality_rule.json")}
  end

  def render("show.json", %{quality_rule: quality_rule}) do
    %{data: render_one(quality_rule, QualityRuleView, "quality_rule.json")}
  end

  def render("quality_rule.json", %{quality_rule: quality_rule}) do
    %{id: quality_rule.id,
      quality_control_id: quality_rule.quality_control_id,
      name: quality_rule.name,
      description: quality_rule.description,
      system: quality_rule.system,
      type_params: quality_rule.type_params,
      type: quality_rule.type}
  end
end
