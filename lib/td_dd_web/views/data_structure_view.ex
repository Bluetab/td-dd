defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view

  alias TdDdWeb.DataStructureView

  require Logger

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
        |> data_structure_json()
        |> add_metadata_versions(data_structure)
        |> add_system_with_keys(data_structure, [:external_id, :id, :name])
        |> add_dynamic_content(data_structure)
        |> add_data_fields(data_structure)
        |> add_versions(data_structure)
        |> add_parents(data_structure)
        |> add_embedded_relations(data_structure)
        |> add_siblings(data_structure)
        |> add_ancestry(data_structure)
        |> add_children(data_structure)
    }
  end

  def render("data_structure.json", %{data_structure: data_structure}) do
    data_structure
    |> data_structure_json()
    |> add_metadata(data_structure)
    |> add_system_with_keys(data_structure, ["external_id", "id", "name"])
    |> add_dynamic_content(data_structure)
  end

  defp data_structure_json(data_structure) do
    dsv_attrs =
      data_structure
      |> Map.get(:versions, [])
      |> Enum.max_by(& &1.version, fn -> %{} end)
      |> Map.take([:class, :description, :metadata, :group, :name, :type, :deleted_at])

    data_structure
    |> Map.take([
      :class,
      :confidential,
      :deleted_at,
      :description,
      :domain_id,
      :domain,
      :external_id,
      :field_type,
      :group,
      :id,
      :inserted_at,
      :links,
      :name,
      :path,
      :system_id,
      :type,
      :updated_at,
      :mutable_metadata
    ])
    |> Map.merge(dsv_attrs)
    |> Map.put_new(:metadata, %{})
    |> Map.put_new(:path, [])
  end

  defp add_system_with_keys(json, data_structure, keys) do
    system_params =
      data_structure
      |> Map.get(:system, %{})
      |> Map.take(keys)

    Map.put(json, :system, system_params)
  end

  defp data_structure_version_embedded(dsv) do
    Map.take(dsv, [:data_structure_id, :id, :name, :type, :deleted_at])
  end

  defp add_dynamic_content(json, data_structure) do
    df_content = Map.get(data_structure, :df_content, %{})

    %{df_content: df_content}
    |> Map.merge(json)
  end

  defp add_children(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :children)

  defp add_parents(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :parents)

  defp add_siblings(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :siblings)

  defp add_embedded_relations(data_structure_json, data_structure),
    do: add_relations(data_structure_json, data_structure, :relations)

  defp add_relations(data_structure_json, data_structure, :relations = type) do
    case Map.get(data_structure, type) do
      nil ->
        data_structure_json

      %{parents: parents, children: children} ->
        parents = Enum.map(parents, &embedded_relation/1)
        children = Enum.map(children, &embedded_relation/1)

        Map.put(data_structure_json, type, %{parents: parents, children: children})
    end
  end

  defp add_relations(data_structure_json, data_structure, type) do
    case Map.get(data_structure, type) do
      nil ->
        data_structure_json

      rs ->
        relations = Enum.map(rs, &data_structure_version_embedded/1)
        Map.put(data_structure_json, type, relations)
    end
  end

  defp embedded_relation(%{version: version, relation: relation, relation_type: relation_type}) do
    structure = data_structure_version_embedded(version)

    Map.new()
    |> Map.put(:id, relation.id)
    |> Map.put(:structure, structure)
    |> Map.put(:relation_type, Map.take(relation_type, [:id, :name, :description]))
  end

  defp add_ancestry(data_structure_json, data_structure) do
    ancestry =
      case Map.get(data_structure, :ancestry) do
        nil ->
          []

        as ->
          as
          |> Enum.map(&Map.take(&1, [:data_structure_id, :name]))
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
    Map.take(data_structure_version, [:version, :deleted_at, :inserted_at, :updated_at])
  end

  defp add_data_fields(data_structure_json, data_structure) do
    field_structures =
      case Map.get(data_structure, :data_fields) do
        nil ->
          []

        fields ->
          Enum.map(fields, &field_structure_json/1)
      end

    Map.put(data_structure_json, :data_fields, field_structures)
  end

  defp add_metadata(data_structure_json, data_structure) do
    case Map.get(data_structure_json, :metadata, %{}) == %{} do
      true ->
        data_structure
        |> Map.get(:metadata, %{})
        |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
        |> Map.merge(data_structure_json, fn _k, v1, v2 -> v2 || v1 end)

      false ->
        data_structure_json
    end
  end

  defp field_structure_json(
         %{
           data_structure_id: data_structure_id,
           class: "field",
           data_structure: %{df_content: df_content, external_id: external_id}
         } = dsv
       ) do
    dsv
    |> Map.take([
      :degree,
      :name,
      :type,
      :metadata,
      :description,
      :deleted_at,
      :inserted_at,
      :links,
      :degree
    ])
    |> lift_metadata()
    |> Map.put(:id, data_structure_id)
    |> Map.put(:external_id, external_id)
    |> Map.put(:has_df_content, not is_nil(df_content))
  end

  defp lift_metadata(%{metadata: metadata} = dsv) do
    metadata = Map.new(metadata, fn {k, v} -> {String.to_atom(k), v} end)

    dsv
    |> Map.delete(:metadata)
    |> Map.merge(metadata)
  end

  defp add_metadata_versions(data_structure_json, %{metadata_versions: versions}) when is_list(versions) do
    versions = Enum.map(versions, &Map.take(&1, [:fields, :version, :id, :deleted_at, :data_structure_id]))
    Map.put(data_structure_json, :metadata_versions, versions)
  end

  defp add_metadata_versions(data_structure_json, _), do: data_structure_json
end
