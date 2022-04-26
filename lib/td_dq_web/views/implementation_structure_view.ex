defmodule TdDqWeb.ImplementationStructureView do
  use TdDqWeb, :view

  alias TdDdWeb.DataStructureView
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation
  alias TdDqWeb.ImplementationStructureView
  alias TdDqWeb.ImplementationView

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
    implementation = Map.get(implementation_structure, :implementation)

    %{
      id: implementation_structure.id,
      deleted_at: implementation_structure.deleted_at,
      data_structure_id: implementation_structure.data_structure_id,
      implementation_id: implementation_structure.implementation_id,
      type: implementation_structure.type
    }
    |> maybe_render_data_structure(data_structure)
    |> maybe_render_implementation(implementation)
  end

  defp maybe_render_data_structure(json, %Ecto.Association.NotLoaded{}), do: json

  defp maybe_render_data_structure(json, %{} = data_structure) do
    Map.put(
      json,
      :data_structure,
      render_one(data_structure, DataStructureView, "implementation_data_structure.json")
    )
  end

  defp maybe_render_data_structure(json, _), do: json

  defp maybe_render_implementation(json, %Ecto.Association.NotLoaded{}), do: json

  defp maybe_render_implementation(json, %Implementation{} = implementation) do
    implementation =
      Implementations.enrich_implementations(implementation, [
        :execution_result_info,
        :current_business_concept_version
      ])

    Map.put(
      json,
      :implementation,
      # render_one(implementation, ImplementationView, "data_structure_implementation.json")
      render_one(implementation, ImplementationView, "implementation.json")
    )
  end

  defp maybe_render_implementation(json, _), do: json
end
