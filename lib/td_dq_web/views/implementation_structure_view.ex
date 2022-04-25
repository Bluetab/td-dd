defmodule TdDqWeb.ImplementationStructureView do
  use TdDqWeb, :view

  alias TdDdWeb.DataStructureView
  alias TdDqWeb.ImplementationStructureView

  def render("index.json", %{implementation_structure: implementation_structure}) do
    %{
      data:
        render_many(
          implementation_structure,
          ImplementationStructureView,
          "implementation_structure.json"
        )
    }
  end

  def render("show.json", %{implementation_structure: implementation_structure}) do
    %{
      data:
        render_one(
          implementation_structure,
          ImplementationStructureView,
          "implementation_structure.json"
        )
    }
  end

  def render("implementation_structure.json", %{
        implementation_structure: implementation_structure
      }) do
    data_structure = Map.get(implementation_structure, :data_structure)

    %{
      id: implementation_structure.id,
      deleted_at: implementation_structure.deleted_at,
      data_structure_id: implementation_structure.data_structure_id,
      implementation_id: implementation_structure.implementation_id,
      type: implementation_structure.type
    }
    |> maybe_render_data_structure(data_structure)
  end

  defp maybe_render_data_structure(json, %{} = data_structure) do
    Map.put(
      json,
      :data_structure,
      render_one(data_structure, DataStructureView, "implementation_data_structure.json")
    )
  end

  defp maybe_render_data_structure(json, _), do: json
end
