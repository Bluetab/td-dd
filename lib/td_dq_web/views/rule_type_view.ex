defmodule TdDqWeb.RuleTypeView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleTypeView

  def render("index.json", %{rule_types: rule_types}) do
    %{data: render_many(rule_types, RuleTypeView, "rule_type.json")}
  end

  def render("show.json", %{rule_type: rule_type}) do
    %{data: render_one(rule_type, RuleTypeView, "rule_type.json")}
  end

  def render("rule_type.json", %{rule_type: rule_type}) do
    %{id: rule_type.id,
      name: rule_type.name,
      params: rule_type.params}
  end
end
