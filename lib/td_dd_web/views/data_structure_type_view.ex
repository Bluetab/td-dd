defmodule TdDdWeb.DataStructureTypeView do
  use TdDdWeb, :view

  def render("index.json", %{data_structure_types: data_structure_types}) do
    %{data: render_many(data_structure_types, __MODULE__, "data_structure_type.json")}
  end

  def render("show.json", %{data_structure_type: data_structure_type} = assigns) do
    %{data: render_one(data_structure_type, __MODULE__, "data_structure_type.json", assigns)}
  end

  def render("data_structure_type.json", %{
        data_structure_type: %{template: %{} = template} = data_structure_type
      }) do
    data_structure_type
    |> update_fields()
    |> Map.take([:id, :name, :filters, :metadata_fields, :metadata_views, :translation])
    |> Map.put(:template, Map.take(template, [:id, :name]))
  end

  def render("data_structure_type.json", %{data_structure_type: %{} = data_structure_type}) do
    data_structure_type
    |> update_fields()
    |> Map.take([
      :id,
      :name,
      :filters,
      :metadata_fields,
      :metadata_views,
      :template_id,
      :translation
    ])
  end

  defp update_fields(%{metadata_fields: fields} = struct) when is_list(fields) do
    %{struct | metadata_fields: Enum.map(fields, & &1.name)}
  end

  defp update_fields(struct) do
    %{struct | metadata_fields: []}
  end
end
