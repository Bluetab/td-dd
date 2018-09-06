defmodule TdDqWeb.RuleResultView do
  use TdDqWeb, :view

  def render("index.json", %{rule_results: rule_results}) do
    %{data: render_many(rule_results, QualityControlsResultsView, "rule_result.json")}
  end

  def render("rule_result.json", %{rule_result: rule_result}) do
    %{
      business_concept_id: rule_result.business_concept_id,
      quality_control_name: rule_result.quality_control_name,
      system: rule_result.system,
      group: rule_result.group,
      structure_name: rule_result.structure_name,
      field_name: rule_result.field_name,
      date: rule_result.date,
      result: rule_result.result,
      inserted_at: rule_result.inserted_at,
      updated_at: rule_result.updated_at
    }
  end
end
