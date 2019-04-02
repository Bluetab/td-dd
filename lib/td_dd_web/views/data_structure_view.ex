defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view
  alias Ecto
  alias TdDdWeb.DataStructureView

  def render("index.json", %{data_structures: data_structures, filters: filters}) do
    %{
      data: render_many(data_structures, DataStructureView, "data_structure.json"),
      filters: filters
    }
  end

  def render("index.json", %{data_structures: data_structures}) do
    %{data: render_many(data_structures, DataStructureView, "data_structure.json")}
  end

  def render("show.json", %{
        data_structure: data_structure,
        user_permissions: user_permissions
      }) do
    "show.json"
    |> render(%{data_structure: data_structure})
    |> Map.put(:user_permissions, user_permissions)
  end

  def render("show.json", %{data_structure: data_structure}) do
    %{
      data:
        data_structure
        |> data_structure_json
        |> add_dynamic_content(data_structure)
        |> add_data_fields(data_structure)
        |> add_versions(data_structure)
        |> add_parents(data_structure)
        |> add_siblings(data_structure)
        |> add_children(data_structure)
    }
  end

  def render("data_structure.json", %{data_structure: data_structure}) do
    data_structure
    |> data_structure_json
    |> add_dynamic_content(data_structure)
  end

  defp data_structure_json(data_structure) do
    %{
      id: data_structure.id,
      system: data_structure.system,
      group: data_structure.group,
      name: data_structure.name,
      description: data_structure.description,
      type: data_structure.type,
      ou: data_structure.ou,
      confidential: data_structure.confidential,
      domain_id: data_structure.domain_id,
      last_change_at: data_structure.last_change_at,
      inserted_at: data_structure.inserted_at,
      metadata: Map.get(data_structure, :metadata, %{})
    }
  end

  defp data_structure_embedded(data_structure) do
    data_structure
    |> Map.take([:id, :name, :type])
  end

  defp add_dynamic_content(json, data_structure) do
    %{
      df_content: data_structure.df_content
    }
    |> Map.merge(json)
  end

  defp add_children(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :children)

  defp add_parents(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :parents)

  defp add_siblings(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :siblings)

  defp add_relations(data_structure_json, data_structure, type) do
    case Map.get(data_structure, type) do
      nil ->
        data_structure_json

      rs ->
        relations = Enum.map(rs, &data_structure_embedded/1)
        Map.put(data_structure_json, type, relations)
    end
  end

  defp add_versions(data_structure_json, data_structure) do
    versions =
      case Map.get(data_structure, :versions) do
        nil -> []
        vs -> Enum.map(vs, &data_structure_version_json/1)
      end

    Map.put(data_structure_json, :versions, versions)
  end

  defp data_structure_version_json(data_structure_version) do
    data_structure_version
    |> Map.take([:version, :inserted_at, :updated_at])
  end

  defp add_data_fields(data_structure_json, data_structure) do
    data_fields =
      case Map.get(data_structure, :data_fields) do
        nil ->
          []

        fields ->
          Enum.reduce(fields, [], fn data_field, acc ->
            json = %{
              id: data_field.id,
              name: data_field.name,
              type: data_field.type,
              precision: data_field.precision,
              metadata: data_field.metadata,
              nullable: data_field.nullable,
              description: data_field.description,
              business_concept_id: data_field.business_concept_id,
              last_change_at: data_field.last_change_at,
              inserted_at: data_field.inserted_at,
              external_id: Map.get(data_field, :external_id, nil),
              bc_related: data_field.bc_related
            }

            [json | acc]
          end)
      end

    Map.put(data_structure_json, :data_fields, data_fields)
  end
end
