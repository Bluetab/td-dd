defmodule TdDqWeb.QualityControlsResultsView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityControlsResultsView

  def render("index.json", %{quality_controls_results: quality_controls_results}) do
    %{data: render_many(quality_controls_results, QualityControlsResultsView, "quality_controls_results.json")}
  end

  def render("quality_controls_results.json", %{quality_controls_results: quality_controls_results}) do
    %{
      business_concept_id: quality_controls_results.business_concept_id,
      quality_control_name: quality_controls_results.quality_control_name,
      system: quality_controls_results.system,
      group: quality_controls_results.group,
      structure_name: quality_controls_results.structure_name,
      field_name: quality_controls_results.field_name,
      date: quality_controls_results.date,
      result: quality_controls_results.result,
      inserted_at: quality_controls_results.inserted_at,
      updated_at: quality_controls_results.updated_at
    }
  end
end
