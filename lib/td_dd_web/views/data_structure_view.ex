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
        |> add_system_with_keys(data_structure, [:external_id, :id, :name])
        |> add_dynamic_content(data_structure)
        |> add_data_fields(data_structure)
        |> add_versions(data_structure)
        |> add_parents(data_structure)
        |> add_siblings(data_structure)
        |> add_ancestry(data_structure)
        |> add_children(data_structure)
    }
  end

  def render("data_structure.json", %{data_structure: data_structure}) do
    data_structure
    |> data_structure_json
    |> add_system_with_keys(data_structure, ["external_id", "id", "name"])
    |> add_dynamic_content(data_structure)
  end

  defp data_structure_json(data_structure) do
    data_structure
    |> Map.take([
      :id,
      :class,
      :confidential,
      :description,
      :domain_id,
      :external_id,
      :group,
      :inserted_at,
      :last_change_at,
      :name,
      :ou,
      :system_id,
      :type,
      :deleted_at
    ])
    |> Map.put(:metadata, Map.get(data_structure, :metadata, %{}))
    |> Map.put(:path, Map.get(data_structure, :path, []))
  end

  defp add_system_with_keys(json, data_structure, keys) do
    system_params =
      data_structure
      |> Map.get(:system)
      |> Map.take(keys)

    Map.put(json, :system, system_params)
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

  defp add_ancestry(data_structure_json, data_structure) do
    ancestry =
      case Map.get(data_structure, :ancestry) do
        nil ->
          []

        as ->
          as
          |> Enum.map(&Map.take(&1, [:id, :name]))
          |> Enum.drop(1)
          |> Enum.reverse()
      end

    Map.put(data_structure_json, :ancestry, ancestry)
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
          Enum.map(
            fields,
            &Map.take(&1, [
              :id,
              :name,
              :type,
              :precision,
              :metadata,
              :nullable,
              :description,
              :last_change_at,
              :inserted_at,
              :external_id,
              :bc_related,
              :field_structure_id,
              :has_df_content
            ])
          )
      end

    Map.put(data_structure_json, :data_fields, data_fields)
  end
end
