defmodule TdDqWeb.QualityControlView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityControlView

  def render("index.json", %{quality_controls: quality_controls}) do
    %{data: render_many(quality_controls, QualityControlView, "quality_control.json")}
  end

  def render("show.json", %{quality_control: quality_control}) do
    %{data: render_one(quality_control, QualityControlView, "quality_control.json")}
  end

  def render("quality_control.json", %{quality_control: quality_control}) do
    %{id: quality_control.id,
      business_concept_id: quality_control.business_concept_id,
      name: quality_control.name,
      description: quality_control.description,
      weight: quality_control.weight,
      priority: quality_control.priority,
      population: quality_control.population,
      goal: quality_control.goal,
      minimum: quality_control.minimum,
      status: quality_control.status,
      version: quality_control.version,
      updated_by: quality_control.updated_by,
      inserted_at: quality_control.inserted_at,
      updated_at: quality_control.updated_at,
      principle: quality_control.principle
    }
    |> add_quality_rules(quality_control)
  end

  defp add_quality_rules(quality_control, qc) do
    case Ecto.assoc_loaded?(qc.quality_rules) do
      true ->
        quality_rules_array = Enum.map(qc.quality_rules, &(%{id: &1.id, name: &1.name, type: &1.type}))
        Map.put(quality_control, :quality_rules, quality_rules_array)
      _ ->
        quality_control
    end
  end
end
