defmodule TdDdWeb.DataStructureVersionView do
  use TdDdWeb, :view
  use TdHypermedia, :view

  alias TdDd.DataStructures
  alias TdDdWeb.DataStructuresTagsView
  alias TdDdWeb.DataStructureTagView
  alias TdDdWeb.GrantView
  alias TdDqWeb.ImplementationStructureView

  @simplified_note_keys [
    "alias"
  ]

  def render("show.json", %{actions: actions} = assigns) do
    "show.json"
    |> render(Map.delete(assigns, :actions))
    |> put_actions(actions)
  end

  def render(
        "show.json",
        %{data_structure_version: dsv, user_permissions: user_permissions, hypermedia: hypermedia} =
          assigns
      ) do
    dsv
    |> render_one_hypermedia(
      hypermedia,
      __MODULE__,
      "show.json",
      Map.drop(assigns, [:hypermedia, :data_structure_version, :user_permissions])
    )
    |> lift_data()
    |> Map.put(:user_permissions, user_permissions)
  end

  def render("show.json", %{data_structure_version: _} = assigns) do
    %{data: render("version.json", assigns)}
  end

  def render("version.json", %{data_structure_version: dsv}) do
    dsv
    |> add_classes()
    |> add_data_structure()
    |> add_data_fields()
    |> add_parents()
    |> add_siblings()
    |> add_children()
    |> add_versions()
    |> add_system()
    |> add_source()
    |> add_ancestry()
    |> add_profile()
    |> add_embedded_relations(dsv)
    |> merge_metadata()
    |> merge_implementations()
    |> add_data_structure_type()
    |> add_cached_content()
    |> add_tags()
    |> add_grant()
    |> add_grants()
    |> clean_published_note()
    |> Map.take([
      :ancestry,
      :children,
      :class,
      :classes,
      :data_fields,
      :data_structure_type,
      :data_structure,
      :degree,
      :deleted_at,
      :description,
      :external_id,
      :grant,
      :grants,
      :group,
      :id,
      :implementations,
      :links,
      :metadata,
      :name,
      :parents,
      :profile,
      :relations,
      :siblings,
      :source,
      :system,
      :tags,
      :type,
      :version,
      :versions,
      :published_note
    ])
  end

  def render("embedded.json", %{data_structure_version: dsv}) do
    Map.take(dsv, [
      :class,
      :deleted_at,
      :description,
      :external_id,
      :group,
      :id,
      :name,
      :path
    ])
  end

  defp add_classes(%{classifications: [_ | _] = classifications} = struct) do
    classes = Map.new(classifications, fn %{name: name, class: class} -> {name, class} end)
    Map.put(struct, :classes, classes)
  end

  defp add_classes(dsv), do: dsv

  defp add_data_structure(%{data_structure: data_structure} = dsv) do
    Map.put(dsv, :data_structure, data_structure_json(data_structure))
  end

  defp data_structure_json(data_structure) do
    data_structure
    |> Map.take([
      :id,
      :confidential,
      :domain_ids,
      :domains,
      :external_id,
      :inserted_at,
      :updated_at,
      :source_id,
      :source,
      :system_id,
      :latest_note
    ])
    |> add_system(data_structure)
    |> add_source()
  end

  defp add_system(json, data_structure) do
    system_params =
      data_structure
      |> Map.get(:system)
      |> Map.take([:external_id, :id, :name])

    Map.put(json, :system, system_params)
  end

  defp data_structure_version_embedded(dsv) do
    dsv
    |> add_classes()
    |> Map.take([
      :data_structure_id,
      :id,
      :name,
      :type,
      :deleted_at,
      :metadata,
      :classes,
      :published_note
    ])
    |> lift_metadata()
    |> clean_published_note()
  end

  defp add_children(data_structure_version), do: add_relations(data_structure_version, :children)

  defp add_parents(data_structure_version), do: add_relations(data_structure_version, :parents)

  defp add_siblings(data_structure_version), do: add_relations(data_structure_version, :siblings)

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

  defp embedded_relation(%{links: links} = struct) do
    struct
    |> Map.delete(:links)
    |> embedded_relation()
    |> Map.put(:links, links)
  end

  defp embedded_relation(%{version: version, relation: relation, relation_type: relation_type}) do
    structure = data_structure_version_embedded(version)

    Map.new()
    |> Map.put(:id, relation.id)
    |> Map.put(:structure, structure)
    |> Map.put(:relation_type, Map.take(relation_type, [:id, :name, :description]))
  end

  defp add_relations(data_structure_version, type) do
    case Map.get(data_structure_version, type) do
      nil ->
        data_structure_version

      %Ecto.Association.NotLoaded{} ->
        data_structure_version

      rs ->
        relations =
          Enum.map(rs, fn r ->
            r
            |> data_structure_version_embedded()
            |> simplify_note()
          end)

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

  defp add_profile(%{class: "field", profile: profile} = dsv) do
    with_profile_attrs(dsv, profile)
  end

  defp add_profile(dsv), do: dsv

  defp field_structure_json(
         %{class: "field", data_structure: %{latest_note: latest_note, profile: profile}} = dsv
       ) do
    dsv
    |> Map.take([
      :data_structure_id,
      :degree,
      :deleted_at,
      :description,
      :inserted_at,
      :links,
      :metadata,
      :name,
      :type
    ])
    |> lift_metadata()
    |> with_profile_attrs(profile)
    |> Map.put(:has_note, not is_nil(latest_note))
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

  defp add_source(dsv) do
    source =
      case Map.get(dsv, :source) do
        nil -> nil
        s -> Map.take(s, [:id, :external_id])
      end

    Map.put(dsv, :source, source)
  end

  def add_ancestry(%{path: [_ | _] = path} = dsv), do: Map.put(dsv, :ancestry, path)
  def add_ancestry(dsv), do: Map.put(dsv, :ancestry, [])

  defp lift_metadata(%{metadata: metadata} = dsv) do
    metadata =
      metadata
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    dsv
    |> Map.delete(:metadata)
    |> Map.merge(metadata)
  end

  defp with_profile_attrs(dsv, %{} = profile) do
    profile =
      profile
      |> Map.take([
        :max,
        :min,
        :most_frequent,
        :null_count,
        :patterns,
        :total_count,
        :unique_count
      ])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    if profile != %{} do
      Map.put(dsv, :profile, profile)
    else
      Map.delete(dsv, :profile)
    end
  end

  defp with_profile_attrs(dsv, _), do: Map.delete(dsv, :profile)

  defp lift_data(%{"data" => data} = attrs) when is_map(data) do
    case Map.get(data, :data) do
      nil ->
        attrs

      nested ->
        Map.put(attrs, "data", nested)
    end
  end

  defp lift_data(attrs), do: attrs

  defp merge_metadata(%{metadata_versions: [_ | _] = metadata_versions} = dsv) do
    %{fields: mutable_metadata} = Enum.max_by(metadata_versions, & &1.version)

    Map.update(dsv, :metadata, mutable_metadata, fn
      nil -> mutable_metadata
      %{} = metadata -> Map.merge(metadata, mutable_metadata)
    end)
  end

  defp merge_metadata(dsv), do: dsv

  defp merge_implementations(%{implementations: [_ | _] = implementations} = dsv) do
    Map.put(
      dsv,
      :implementations,
      render_many(implementations, ImplementationStructureView, "implementation_structure.json")
    )
  end

  defp merge_implementations(dsv), do: dsv

  defp add_data_structure_type(%{data_structure_type: nil} = dsv),
    do: Map.put(dsv, :data_structure_type, %{})

  defp add_data_structure_type(%{data_structure_type: %{} = data_structure_type} = dsv) do
    data_structure_type =
      Map.take(data_structure_type, [:template_id, :translation, :metadata_views])

    Map.put(dsv, :data_structure_type, data_structure_type)
  end

  defp add_data_structure_type(dsv), do: Map.put(dsv, :data_structure_type, %{})

  defp add_cached_content(dsv) do
    structure = Map.get(dsv, :data_structure)

    latest_note =
      structure
      |> Map.get(:latest_note, %{})
      |> DataStructures.get_cached_content(dsv)

    structure = Map.put(structure, :latest_note, latest_note)
    Map.put(dsv, :data_structure, structure)
  end

  defp clean_published_note(%{published_note: %{df_content: %{} = content}} = dsv) do
    latest_note = DataStructures.get_cached_content(content, dsv)
    Map.put(dsv, :published_note, latest_note)
  end

  defp clean_published_note(%{published_note: _} = dsv) do
    Map.drop(dsv, [:published_note])
  end

  defp clean_published_note(dsv), do: dsv

  defp simplify_note(%{published_note: %{} = note} = dsv) do
    Map.put(dsv, :published_note, Map.take(note, @simplified_note_keys))
  end

  defp simplify_note(dsv), do: dsv

  defp add_tags(ds) do
    tags =
      case Map.get(ds, :tags) do
        nil -> []
        tags -> render_many(tags, DataStructuresTagsView, "data_structures_tags.json")
      end

    Map.put(ds, :tags, tags)
  end

  defp add_grant(ds) do
    grant =
      case Map.get(ds, :grant) do
        nil -> nil
        grant -> render_one(grant, GrantView, "grant.json")
      end

    Map.put(ds, :grant, grant)
  end

  defp add_grants(%{grants: grants} = ds) when is_list(grants) do
    Map.put(ds, :grants, render_many(grants, GrantView, "grant.json"))
  end

  defp add_grants(ds), do: ds

  defp put_actions(ds, %{manage_tags: tags}) when is_list(tags) do
    tags = render_many(tags, DataStructureTagView, "embedded.json")
    actions = %{manage_tags: %{data: tags}}
    Map.update(ds, "_actions", actions, &Map.merge(&1, actions))
  end

  defp put_actions(ds, _), do: ds
end
