defmodule TdDdWeb.DataStructureVersionView do
  use TdDdWeb, :view

  alias TdDd.DataStructures
  alias TdDdWeb.GrantView
  alias TdDdWeb.StructureTagView

  @protected DataStructures.protected()

  def render("show.json", %{actions: actions} = assigns) do
    "show.json"
    |> render(Map.delete(assigns, :actions))
    |> put_actions(actions)
  end

  def render("show.json", %{user_permissions: user_permissions} = assigns) do
    "show.json"
    |> render(Map.delete(assigns, :user_permissions))
    |> Map.put(:user_permissions, user_permissions)
  end

  def render("show.json", %{data_structure_version: _} = assigns) do
    %{data: render("version.json", assigns)}
  end

  def render("version.json", %{data_structure_version: dsv} = assigns) do
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
    |> add_data_structure_type()
    |> add_note()
    |> add_tags(assigns)
    |> add_grant()
    |> add_grants()
    |> add_data_structure_links()
    |> Map.take([
      :alias,
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
      :implementation_count,
      :links,
      :data_structure_link_count,
      :metadata,
      :name,
      :note,
      :parents,
      :profile,
      :relations,
      :siblings,
      :source,
      :system,
      :tags,
      :type,
      :version,
      :versions
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
      :alias,
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

  defp data_structure_version_embedded(%{data_structure: %{alias: alias_name}} = dsv) do
    dsv
    |> add_classes()
    |> Map.take([
      :data_structure_id,
      :id,
      :name,
      :type,
      :deleted_at,
      :metadata,
      :classes
    ])
    |> Map.put(:alias, alias_name)
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
    %{
      id: relation.id,
      structure: data_structure_version_embedded(version),
      relation_type: Map.take(relation_type, [:id, :name, :description])
    }
  end

  defp add_relations(data_structure_version, type) do
    case Map.get(data_structure_version, type) do
      nil ->
        data_structure_version

      %Ecto.Association.NotLoaded{} ->
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

  defp add_profile(%{class: "field", profile: profile} = dsv) do
    with_profile_attrs(dsv, profile)
  end

  defp add_profile(dsv), do: Map.delete(dsv, :profile)

  defp field_structure_json(
         %{
           class: "field",
           data_structure: %{profile: profile, alias: alias_name}
         } = dsv
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
    |> with_profile_attrs(profile)
    |> Map.put(:alias, alias_name)
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
    Map.take(version, [:version, :deleted_at, :inserted_at, :updated_at])
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

  defp merge_metadata(%{metadata_versions: [_ | _] = metadata_versions} = dsv) do
    %{fields: mutable_metadata} =
      Enum.max_by(metadata_versions, & &1.version)
      |> case do
        %{deleted_at: deleted_at} = _version when deleted_at != nil ->
          %{fields: %{}}

        version ->
          version
      end

    Map.update(dsv, :metadata, mutable_metadata, fn
      nil ->
        mutable_metadata

      %{} = metadata ->
        Map.merge(
          metadata,
          mutable_metadata,
          fn
            # Merge metadata and mutable_metadata @protected fields.
            # If there is a conflict in the @protected content, the one from
            # mutable metadata (rightmost in the Map.merge) will prevail.
            @protected, mp, mmp -> Map.merge(mp, mmp)
            _key, _mp, mmp -> mmp
          end
        )
    end)
  end

  defp merge_metadata(dsv), do: dsv

  defp add_data_structure_type(%{data_structure_type: nil} = dsv),
    do: Map.put(dsv, :data_structure_type, %{})

  defp add_data_structure_type(%{data_structure_type: %{} = data_structure_type} = dsv) do
    data_structure_type =
      Map.take(data_structure_type, [:template_id, :translation, :metadata_views])

    Map.put(dsv, :data_structure_type, data_structure_type)
  end

  defp add_data_structure_type(dsv), do: Map.put(dsv, :data_structure_type, %{})

  defp add_note(%{data_structure: %{published_note: %{df_content: %{} = content}}} = dsv) do
    %{dsv | note: DataStructures.get_cached_content(content, dsv)}
  end

  defp add_note(%{published_note: %{df_content: %{} = content}} = dsv) do
    %{dsv | note: DataStructures.get_cached_content(content, dsv)}
  end

  defp add_note(dsv), do: dsv

  defp add_data_structure_links(%{data_structure_links: data_structure_link_count} = ds) do
    Map.put(
      ds,
      :data_structure_link_count,
      data_structure_link_count
    )
  end

  defp add_data_structure_links(ds), do: ds

  defp add_tags(ds, %{tags: tags}) when is_list(tags) do
    Map.put(ds, :tags, render_many(tags, StructureTagView, "structure_tag.json"))
  end

  defp add_tags(ds, _), do: ds

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

  defp put_actions(ds, actions) do
    Map.update(ds, "_actions", transform_create_link(actions), &Map.merge(&1, actions))
  end

  defp transform_create_link(%{create_link: true} = actions), do: %{actions | create_link: %{}}
  defp transform_create_link(actions), do: actions
end
