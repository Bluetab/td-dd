defmodule TdDdWeb.DataStructureVersionView do
  use TdDdWeb, :view

  def render("show.json", %{data_structure_version: dsv}) do
    %{
      data:
        dsv
        |> add_data_structure
        |> add_children
        |> add_data_fields
        |> add_versions
        |> Map.take([:data_structure, :children, :data_fields, :version, :id])
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
      :system,
      :group,
      :name,
      :description,
      :type,
      :ou,
      :domain_id,
      :last_change_at,
      :inserted_at
    ])
  end

  defp add_children(data_structure_version) do
    children =
      case Map.get(data_structure_version, :children) do
        nil -> []
        cs -> Enum.map(cs, &data_structure_json/1)
      end

    Map.put(data_structure_version, :children, children)
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
end
