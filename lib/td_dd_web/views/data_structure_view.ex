defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view

  alias TdDd.DataStructures
  alias TdDdWeb.DataStructureVersionView
  alias TdDdWeb.StructureTagView

  def render("index.json", %{actions: %{} = actions} = assigns) when map_size(actions) > 0 do
    "index.json"
    |> render(Map.delete(assigns, :actions))
    |> Map.put(:_actions, actions)
  end

  def render("index.json", %{scroll_id: scroll_id} = assigns) do
    "index.json"
    |> render(Map.delete(assigns, :scroll_id))
    |> Map.put(:scroll_id, scroll_id)
  end

  def render("index.json", %{data_structures: data_structures, filters: filters}) do
    %{
      data: render_many(data_structures, __MODULE__, "data_structure.json"),
      filters: filters
    }
  end

  def render("index.json", %{data_structures: data_structures}) do
    %{data: render_many(data_structures, __MODULE__, "data_structure.json")}
  end

  def render("show.json", %{data_structure: data_structure, user_permissions: user_permissions}) do
    "show.json"
    |> render(%{data_structure: data_structure})
    |> Map.put(:user_permissions, user_permissions)
  end

  def render("show.json", %{data_structure: data_structure} = assigns) do
    %{
      data:
        data_structure
        |> data_structure_json()
        |> add_tags(assigns)
        |> add_metadata_versions(data_structure)
        |> add_system_with_keys(data_structure, [:external_id, :id, :name])
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
    |> maybe_put_note(data_structure)
  end

  def render("implementation_data_structure.json", %{
        data_structure: %{current_version: current_version} = data_structure
      }) do
    data_structure
    |> data_structure_json()
    |> add_system_with_keys(data_structure, [:external_id, :id, :name])
    |> Map.put(
      :current_version,
      render_one(current_version, DataStructureVersionView, "embedded.json")
    )
  end

  def render("embedded.json", %{
        data_structure: %{id: id, external_id: external_id, current_version: current_version}
      }) do
    case current_version do
      %{name: name, type: type, metadata: metadata, path: path} ->
        %{
          id: id,
          external_id: external_id,
          name: name,
          type: type,
          metadata: metadata,
          path: path
        }

      %{name: name, type: type, metadata: metadata} ->
        %{id: id, external_id: external_id, name: name, type: type, metadata: metadata}

      _ ->
        %{id: id, external_id: external_id}
    end
  end

  defp data_structure_json(data_structure) do
    dsv_attrs =
      data_structure
      |> Map.get(:versions, [])
      |> case do
        [_ | _] = versions ->
          versions
          |> Enum.max_by(& &1.version, fn -> %{} end)
          |> Map.take([:class, :description, :metadata, :group, :name, :type, :deleted_at])

        _ ->
          %{}
      end

    data_structure
    |> Map.take([
      :class,
      :classes,
      :confidential,
      :deleted_at,
      :description,
      :domain_ids,
      :domains,
      :external_id,
      :field_type,
      :group,
      :id,
      :inserted_at,
      :linked_concepts,
      :links,
      :name,
      :original_name,
      :parent,
      :path,
      :source_id,
      :source,
      :system_id,
      :type,
      :updated_at,
      :mutable_metadata,
      :metadata,
      :version
    ])
    |> Map.merge(dsv_attrs)
    |> Map.put_new(:metadata, %{})
    |> Map.put_new(:path, [])
    |> add_source()
  end

  defp add_system_with_keys(json, data_structure, keys) do
    system_params =
      data_structure
      |> Map.get(:system, %{})
      |> Map.take(keys)

    Map.put(json, :system, system_params)
  end

  defp data_structure_version_embedded(dsv) do
    dsv
    |> Map.take([:data_structure_id, :id, :name, :type, :deleted_at, :metadata])
  end

  defp maybe_put_note(json, data_structure) do
    latest_note =
      data_structure
      |> Map.get(:note, %{})
      |> DataStructures.get_cached_content(data_structure)

    Map.put_new(json, :note, latest_note)
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
      case Map.get(data_structure, :path) do
        %{structure_ids: [_ | ids], names: [_ | names]} ->
          [ids, names]
          |> Enum.zip()
          |> Enum.map(fn {id, name} -> %{data_structure_id: id, name: name} end)
          |> Enum.reverse()

        _ ->
          []
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
           data_structure: %{external_id: external_id}
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
    |> Map.put(:id, data_structure_id)
    |> Map.put(:external_id, external_id)
  end

  defp add_metadata_versions(data_structure_json, %{metadata_versions: versions})
       when is_list(versions) do
    versions =
      Enum.map(versions, &Map.take(&1, [:fields, :version, :id, :deleted_at, :data_structure_id]))

    Map.put(data_structure_json, :metadata_versions, versions)
  end

  defp add_metadata_versions(data_structure_json, _), do: data_structure_json

  defp add_source(ds) do
    source =
      case Map.get(ds, :source) do
        nil -> nil
        s -> Map.take(s, [:id, :external_id])
      end

    Map.put(ds, :source, source)
  end

  # TODO: tags not consumed by front?
  defp add_tags(ds, %{tags: tags} = _assigns) do
    Map.put(ds, :tags, render_many(tags, StructureTagView, "structure_tag.json"))
  end

  defp add_tags(ds, _), do: ds
end
