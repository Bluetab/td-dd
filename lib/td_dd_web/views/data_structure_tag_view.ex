defmodule TdDdWeb.DataStructureTagView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructureTagView

  def render("index.json", %{data_structure_tags: data_structure_tags}) do
    %{data: render_many(data_structure_tags, DataStructureTagView, "data_structure_tag.json")}
  end

  def render("show.json", %{data_structure_tag: data_structure_tag}) do
    %{data: render_one(data_structure_tag, DataStructureTagView, "data_structure_tag.json")}
  end

  def render("data_structure_tag.json", %{data_structure_tag: data_structure_tag}) do
    %{
      id: data_structure_tag.id,
      name: data_structure_tag.name
    }
    |> with_structure_count(data_structure_tag)
  end

  defp with_structure_count(json, %{tagged_structures: structures}) when is_list(structures) do
    Map.put(json, :structure_count, Enum.count(structures))
  end

  defp with_structure_count(json, _), do: json
end
