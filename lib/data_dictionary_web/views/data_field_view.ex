defmodule DataDictionaryWeb.DataFieldView do
  use DataDictionaryWeb, :view
  alias DataDictionaryWeb.DataFieldView

  def render("index.json", %{data_fields: data_fields}) do
    %{data: render_many(data_fields, DataFieldView, "data_field.json")}
  end

  def render("show.json", %{data_field: data_field}) do
    %{data: render_one(data_field, DataFieldView, "data_field.json")}
  end

  def render("data_field.json", %{data_field: data_field}) do
    %{id: data_field.id,
      name: data_field.name,
      type: data_field.type,
      precision: data_field.precision,
      nullable: data_field.nullable,
      description: data_field.description,
      business_concept_id: data_field.business_concept_id,
      data_structure_id: data_field.data_structure_id,
      last_change: data_field.last_change,
      modifier: data_field.modifier}
  end
end
