defmodule TdDdWeb.DataStructureTypeView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructureTypeView

  def render("index.json", %{data_structure_types: data_structure_types}) do
    %{data: render_many(data_structure_types, DataStructureTypeView, "data_structure_type.json")}
  end

  def render("show.json", %{data_structure_type: data_structure_type}) do
    %{data: render_one(data_structure_type, DataStructureTypeView, "data_structure_type.json")}
  end

  def render("data_structure_type.json", %{data_structure_type: %{template: template} = data_structure_type}) do
    %{id: data_structure_type.id,
      structure_type: data_structure_type.structure_type,
      translation: data_structure_type.translation,
      template: %{id: template.id, name: template.name}
    }
  end

  def render("data_structure_type.json", %{data_structure_type: data_structure_type}) do
    %{id: data_structure_type.id,
      structure_type: data_structure_type.structure_type,
      translation: data_structure_type.translation,
      template_id: data_structure_type.template_id}
  end
end
