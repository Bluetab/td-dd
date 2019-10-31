defmodule TdDdWeb.DataStructureVersionView do
  use TdDdWeb, :view

  alias TdHypermedia.View

  def render("show.json", %{data_structure_version: dsv}) do
    View.with_actions(
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
            :ancestry,
            :children,
            :class,
            :data_fields,
            :data_structure,
            :deleted_at,
            :description,
            :group,
            :id,
            :links,
            :name,
            :parents,
            :siblings,
            :system,
            :type,
            :version,
            :versions
          ])
      },
      dsv
    )
  end

  defp add_data_structure(%{data_structure: data_structure} = dsv) do
    Map.put(dsv, :data_structure, data_structure_json(data_structure))
  end

  defp data_structure_json(data_structure) do
    data_structure
    |> Map.take([
      :id,
      :confidential,
      :domain_id,
      :external_id,
      :inserted_at,
      :updated_at,
      :ou,
      :system_id,
      :df_content
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

  defp data_structure_version_embedded(dsv) do
    Map.take(dsv, [:data_structure_id, :id, :name, :type, :deleted_at])
  end

  defp add_children(data_structure_version), do: add_relations(data_structure_version, :children)

  defp add_parents(data_structure_version), do: add_relations(data_structure_version, :parents)

  defp add_siblings(data_structure_version), do: add_relations(data_structure_version, :siblings)

  defp add_relations(data_structure_version, type) do
    case Map.get(data_structure_version, type) do
      nil ->
        data_structure_version

      rs ->
        relations = Enum.map(rs, &data_structure_version_embedded/1)
        Map.put(data_structure_version, type, relations)
    end
  end

  defp add_data_fields(%{data_fields: data_fields} = dsv) do
    field_structures = Enum.map(data_fields, &field_structure_json/1)
    Map.put(dsv, :data_fields, field_structures)
  end

  defp add_data_fields(dsv) do
    Map.put(dsv, :data_fields, [])
  end

  defp field_structure_json(
         %{class: "field", data_structure: %{df_content: df_content, profile: profile}} = dsv
       ) do
    dsv
    |> Map.take([
      :name,
      :data_structure_id,
      :external_id,
      :type,
      :metadata,
      :description,
      :deleted_at,
      :inserted_at,
      :links
    ])
    |> lift_metadata()
    |> with_profile_attrs(profile)
    |> Map.put(:has_df_content, not is_nil(df_content))
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
    |> Map.take([:version, :deleted_at, :inserted_at, :updated_at])
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
          |> Enum.map(&Map.take(&1, [:data_structure_id, :name]))
          |> Enum.reverse()
      end

    Map.put(dsv, :ancestry, ancestry)
  end

  defp lift_metadata(%{metadata: metadata} = dsv) do
    metadata =
      metadata
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    dsv
    |> Map.delete(:metadata)
    |> Map.merge(metadata)
  end

  defp with_profile_attrs(dsv, %{value: value}) do
    profile =
      value
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    Map.put(dsv, :profile, profile)
  end

  defp with_profile_attrs(dsv, _), do: dsv

  # defp lift_data(%{"data" => data} = attrs) when is_map(data) do
  #   case Map.get(data, :data) do
  #     nil ->
  #       attrs

  #     nested ->
  #       Map.put(attrs, "data", nested)
  #   end
  # end

  # defp lift_data(attrs), do: attrs
end
