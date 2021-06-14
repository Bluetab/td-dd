defmodule TdDdWeb.DataStructuresTagsView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructuresTagsView
  alias TdDdWeb.DataStructureTagView

  def render("show.json", %{link: link}) do
    %{
      data: render_one(link, DataStructuresTagsView, "data_structures_tags.json")
    }
  end

  def render("index.json", %{links: links}) do
    %{data: render_many(links, DataStructuresTagsView, "data_structures_tags.json")}
  end

  def render("data_structures_tags.json", %{data_structures_tags: data_structures_tags = %{}}) do
    %{
      id: data_structures_tags.id,
      description: data_structures_tags.description,
      updated_at: data_structures_tags.updated_at,
      inserted_at: data_structures_tags.inserted_at,
      _embedded: %{
        data_structure: structure_json(data_structures_tags.data_structure),
        data_structure_tag:
          render_one(
            data_structures_tags.data_structure_tag,
            DataStructureTagView,
            "data_structure_tag.json"
          )
      }
    }
  end

  def render("data_structures_tags.json", %{data_structures_tags: data_structures_tags})
      when is_binary(data_structures_tags) do
    data_structures_tags
  end

  defp structure_json(data_structure) do
    Map.take(data_structure, [:id, :external_id])
  end
end
