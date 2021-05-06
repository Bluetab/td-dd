defmodule TdDdWeb.DataStructuresTagsView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructureTagView

  def render("show.json", %{link: link}) do
    %{
      data: %{
        id: link.id,
        description: link.description,
        _embedded: %{
          data_structure: structure_json(link.data_structure),
          data_structure_tag:
            render_one(link.data_structure_tag, DataStructureTagView, "data_structure_tag.json")
        }
      }
    }
  end

  defp structure_json(data_structure) do
    Map.take(data_structure, [:id, :external_id])
  end
end
