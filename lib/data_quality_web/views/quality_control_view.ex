defmodule DataQualityWeb.QualityControlView do
  use DataQualityWeb, :view
  alias DataQualityWeb.QualityControlView

  def render("index.json", %{quality_controls: quality_controls}) do
    %{data: render_many(quality_controls, QualityControlView, "quality_control.json")}
  end

  def render("show.json", %{quality_control: quality_control}) do
    %{data: render_one(quality_control, QualityControlView, "quality_control.json")}
  end

  def render("quality_control.json", %{quality_control: quality_control}) do
    %{id: quality_control.id,
      type: quality_control.type,
      business_concept_id: quality_control.business_concept_id,
      name: quality_control.name,
      description: quality_control.description,
      weight: quality_control.weight,
      priority: quality_control.priority,
      population: quality_control.population,
      goal: quality_control.goal,
      minimum: quality_control.minimum}
  end
end
