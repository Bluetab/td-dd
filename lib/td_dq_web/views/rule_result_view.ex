defmodule TdDqWeb.RuleResultView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleResultView

  def render("index.json", %{rule_results: rule_results}) do
    %{data: render_many(rule_results, RuleResultView, "rule_result.json")}
  end

  def render("rule_result.json", %{rule_result: rule_result}) do
    %{
      rule_implementation_id: rule_result.rule_implementation_id,
      date: rule_result.date,
      result: rule_result.result
    }
  end
end
