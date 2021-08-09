defmodule TdDdWeb.DataStructureTypeView do
  use TdDdWeb, :view

  alias TdDdWeb.DataStructureTypeView

  def render("index.json", %{data_structure_types: data_structure_types}) do
    %{data: render_many(data_structure_types, DataStructureTypeView, "data_structure_type.json")}
  end

  def render("show.json", %{data_structure_type: data_structure_type}) do
    %{data: render_one(data_structure_type, DataStructureTypeView, "data_structure_type.json")}
  end

  def render("data_structure_type.json", %{
        data_structure_type: %{template: %{} = template} = data_structure_type
      }) do
    data_structure_type
    |> Map.take([:id, :name, :translation, :metadata_fields, :metadata_views])
    |> Map.put(:template, Map.take(template, [:id, :name]))
  end

  def render("data_structure_type.json", %{data_structure_type: %{} = data_structure_type}) do
    Map.take(data_structure_type, [
      :id,
      :name,
      :translation,
      :metadata_fields,
      :metadata_views,
      :template_id
    ])
  end
end
