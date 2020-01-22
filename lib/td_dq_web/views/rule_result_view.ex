defmodule TdDqWeb.RuleResultView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleResultView

  def render("index.json", %{rule_results: rule_results}) do
    %{data: render_many(rule_results, RuleResultView, "rule_result.json")}
  end

  def render("rule_result.json", %{rule_result: rule_result}) do
    %{
      implementation_key: rule_result.implementation_key,
      date: rule_result.date,
      result: rule_result.result,
      records: Map.get(rule_result, :records),
      errors: Map.get(rule_result, :errors)
    }
  end
end
