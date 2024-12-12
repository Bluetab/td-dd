defmodule TdDdWeb.StructureTagSearchView do
  use TdDdWeb, :view

  def render("index.json", %{structure_tags: structure_tags}) do
    %{
      data: render_many(structure_tags, __MODULE__, "structure_tag.json")
    }
  end

  def render("structure_tag.json", %{structure_tag_search: structure_tag}) do
    Map.take(structure_tag, [
      :id,
      :data_structure_id,
      :tag_id,
      :comment,
      :inserted_at,
      :updated_at
    ])
  end
end
