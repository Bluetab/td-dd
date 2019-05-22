defmodule TdDdWeb.DataStructureVersionView do
  use TdDdWeb, :view

  def render("show.json", %{data_structure_version: dsv}) do
    %{
      data:
        dsv
        |> add_data_structure
        |> add_data_fields
        |> add_parents
        |> add_siblings
        |> add_children
        |> add_versions
        |> add_system
        |> add_ancestry
        |> Map.take([
          :data_structure,
          :ancestry,
          :children,
          :parents,
          :siblings,
          :data_fields,
          :system,
          :version,
          :versions,
          :id
        ])
    }
  end

  defp add_data_structure(%{data_structure: data_structure} = dsv) do
    dsv
    |> Map.put(:data_structure, data_structure_json(data_structure))
  end

  defp data_structure_json(data_structure) do
    data_structure
    |> Map.take([
      :id,
      :group,
      :name,
      :description,
      :type,
      :ou,
      :confidential,
      :domain_id,
      :last_change_at,
      :inserted_at
    ])
    |> add_system(data_structure)
  end

  defp add_system(json, data_structure) do
    system_params =
      data_structure
      |> Map.get(:system)
      |> Map.take([:external_id, :id, :name])

    Map.put(json, :system, system_params)
  end

  defp data_structure_embedded(data_structure) do
    data_structure
    |> Map.take([:id, :name, :type])
  end

  defp add_children(data_structure_version), do: add_relations(data_structure_version, :children)

  defp add_parents(data_structure_version), do: add_relations(data_structure_version, :parents)

  defp add_siblings(data_structure_version), do: add_relations(data_structure_version, :siblings)

  defp add_relations(data_structure_version, type) do
    case Map.get(data_structure_version, type) do
      nil ->
        data_structure_version

      rs ->
        relations = Enum.map(rs, &data_structure_embedded/1)
        Map.put(data_structure_version, type, relations)
    end
  end

  defp add_data_fields(%{data_fields: fields} = dsv) do
    data_fields =
      fields
      |> Enum.map(
        &Map.take(&1, [
          :id,
          :name,
          :type,
          :precision,
          :nullable,
          :description,
          :last_change_at,
          :inserted_at
        ])
      )

    Map.put(dsv, :data_fields, data_fields)
  end

  defp add_data_fields(dsv) do
    Map.put(dsv, :data_fields, [])
  end

  defp add_versions(dsv) do
    versions =
      case Map.get(dsv, :versions) do
        nil -> []
        vs -> Enum.map(vs, &version_json/1)
      end

    Map.put(dsv, :versions, versions)
  end

  defp version_json(version) do
    version
    |> Map.take([:version, :inserted_at, :updated_at])
  end

  defp add_system(dsv) do
    system =
      case Map.get(dsv, :system) do
        nil -> nil
        s -> Map.take(s, [:id, :name])
      end

    Map.put(dsv, :system, system)
  end

  defp add_ancestry(dsv) do
    ancestry =
      case Map.get(dsv, :ancestry) do
        nil ->
          []

        as ->
          as
          |> Enum.map(&Map.take(&1, [:id, :name]))
          |> Enum.drop(1)
          |> Enum.reverse()
      end

    Map.put(dsv, :ancestry, ancestry)
  end

end
