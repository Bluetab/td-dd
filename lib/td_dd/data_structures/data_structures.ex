defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdCx.Sources
  alias TdCx.Sources.Source
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Grants
  alias TdDd.Lineage.GraphData
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker
  alias TdDd.Search.StructureVersionEnricher
  alias TdDfLib.Format

  # Data structure version associations preloaded for some views
  @preload_dsv_assocs [
    :published_note,
    :structure_type,
    :classifications,
    data_structure: :system
  ]

  def list_data_structures(clauses \\ %{}) do
    clauses
    |> DataStructureQueries.data_structures_query()
    |> Repo.all()
  end

  def list_data_structure_versions(clauses \\ %{}) do
    clauses
    |> Enum.reduce(DataStructureVersion, fn
      {:since, since}, q -> where(q, [dsv], dsv.updated_at >= ^since or dsv.deleted_at >= ^since)
      {:min_id, id}, q -> where(q, [dsv], dsv.id >= ^id)
      {:order_by, "id"}, q -> order_by(q, :id)
      {:limit, limit}, q -> limit(q, ^limit)
    end)
    |> Repo.all()
  end

  def get_data_structure!(id, preload \\ [:system]) do
    DataStructure
    |> Repo.get!(id)
    |> Repo.preload(preload)
  end

  def get_data_structure(id), do: Repo.get(DataStructure, id)

  def list_data_structure_versions_by_criteria(criteria) do
    criteria
    |> Enum.reduce(DataStructureVersion, fn
      {:not_deleted, _}, q ->
        where(q, [dsv], is_nil(dsv.deleted_at))

      {:name, name}, q ->
        where(q, [dsv], fragment("lower(?)", dsv.name) == ^name)

      {:name_in, names}, q ->
        where(q, [dsv], fragment("lower(?)", dsv.name) in ^names)

      {:class, class}, q ->
        where(q, [dsv], dsv.class == ^class)

      {:metadata_field, {key, value}}, q ->
        where(q, [dsv], fragment("lower(?->>?) = ?", dsv.metadata, ^key, ^value))

      {:metadata_field_in, {key, value}}, q ->
        where(q, [dsv], fragment("lower(?->>?) = ANY(?)", dsv.metadata, ^key, ^value))

      {:source_id, source_id}, q ->
        q
        |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
        |> where([_dsv, ds], ds.source_id == ^source_id)
    end)
    |> Repo.all()
  end

  @doc "Gets a single data_structure by external_id"
  def get_data_structure_by_external_id(external_id, preload \\ []) do
    Repo.get_by(DataStructure, external_id: external_id)
    |> Repo.preload(preload)
  end

  def get_data_structures(ids, preload \\ :system) do
    from(ds in DataStructure, where: ds.id in ^ids, preload: ^preload, select: ds)
    |> Repo.all()
  end

  @doc "Gets a single data_structure_version"
  def get_data_structure_version!(id) do
    enriched_structure_version!(id)
  end

  def get_data_structure_version!(data_structure_version_id, opts) do
    data_structure_version_id
    |> get_data_structure_version!()
    |> enrich(opts)
  end

  def get_data_structure_version!(data_structure_id, version, opts) do
    DataStructureVersion
    |> Repo.get_by!(data_structure_id: data_structure_id, version: version)
    |> Map.get(:id)
    |> enriched_structure_version!(preload: @preload_dsv_assocs)
    |> enrich(opts)
  end

  def get_cached_content(%{} = content, %{structure_type: %{template_id: template_id}}) do
    get_cached_content(content, %{data_structure_type: %{template_id: template_id}})
  end

  def get_cached_content(%{} = content, %{data_structure_type: %{template_id: template_id}}) do
    case TemplateCache.get(template_id) do
      {:ok, template} ->
        Format.enrich_content_values(content, template)

      _ ->
        content
    end
  end

  def get_cached_content(content, _structure), do: content

  defp enrich(nil = _target, _opts), do: nil

  defp enrich(target, nil = _opts), do: target

  defp enrich(%DataStructureVersion{id: id} = _data_structure_version, :defaults) do
    enriched_structure_version!(id, preload: [data_structure: :source])
  end

  defp enrich(%DataStructureVersion{} = dsv, opts) do
    deleted = not is_nil(Map.get(dsv, :deleted_at))
    with_confidential = Enum.member?(opts, :with_confidential)

    dsv
    |> enrich(:defaults)
    |> enrich(opts, :classifications, &get_classifications!/1)
    |> enrich(opts, :system, &get_system!/1)
    |> enrich(
      opts,
      :parents,
      &get_parents(&1, deleted: deleted, with_confidential: with_confidential)
    )
    |> enrich(
      opts,
      :children,
      &get_children(&1, deleted: deleted, with_confidential: with_confidential)
    )
    |> enrich(
      opts,
      :siblings,
      &get_siblings(&1, deleted: deleted, with_confidential: with_confidential)
    )
    |> enrich(
      opts,
      :data_fields,
      &get_field_structures(&1,
        deleted: deleted,
        preload:
          if(Enum.member?(opts, :profile),
            do: [:published_note, data_structure: :profile],
            else: []
          ),
        with_confidential: with_confidential
      )
    )
    |> enrich(opts, :data_field_degree, &get_field_degree/1)
    |> enrich(opts, :data_field_links, &get_field_links/1)
    |> enrich(
      opts,
      :relations,
      &get_relations(&1, deleted: deleted, default: false, with_confidential: with_confidential)
    )
    |> enrich(opts, :relation_links, &get_relation_links/1)
    |> enrich(opts, :versions, &get_versions!/1)
    |> enrich(opts, :degree, &get_degree/1)
    |> enrich(opts, :profile, &get_profile!/1)
    |> enrich(opts, :links, &get_structure_links/1)
    |> enrich(opts, :source, &get_source!/1)
    |> enrich(opts, :metadata_versions, &get_metadata_versions!/1)
    |> enrich(opts, :data_structure_type, &get_data_structure_type!/1)
    |> enrich(opts, :tags, &get_tags!/1)
    |> enrich(opts, :grants, &get_grants/1)
    |> enrich(opts, :grant, &get_grant(&1, opts[:user_id]))
    |> enrich(opts, :implementations, &get_implementations!/1)
    |> enrich(opts, :published_note, &get_published_note!/1)
  end

  defp enrich(%{} = target, opts, key, fun) do
    target_key = get_target_key(key)

    case Enum.member?(opts, key) do
      false -> target
      true -> Map.put(target, target_key, fun.(target))
    end
  end

  defp get_published_note!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, :published_note) do
      %{published_note: published_note} -> published_note
    end
  end

  defp get_target_key(:data_field_degree), do: :data_fields
  defp get_target_key(:data_field_links), do: :data_fields
  defp get_target_key(:relation_links), do: :relations
  defp get_target_key(key), do: key

  defp get_system!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :system) do
      %{data_structure: %{system: system}} -> system
    end
  end

  defp get_classifications!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, :classifications) do
      %{classifications: classifications} -> classifications
    end
  end

  defp get_profile!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :profile) do
      %{data_structure: %{profile: profile}} -> profile
    end
  end

  def get_data_structure_type!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, :structure_type) do
      %{structure_type: structure_type} -> structure_type
    end
  end

  def get_data_structure_type(%DataStructure{current_version: %{structure_type: %{name: type}}}) do
    type
  end

  def get_data_structure_type(_data_structure), do: nil

  def get_field_structures(data_structure_version, opts) do
    data_structure_version
    |> Ecto.assoc(:children)
    |> where(class: "field")
    |> join(:inner, [child], child_ds in assoc(child, :data_structure), as: :child_ds)
    |> with_confidential(
      Keyword.get(opts, :with_confidential),
      dynamic([child_ds: child_ds], child_ds.confidential == false)
    )
    |> with_deleted(opts, dynamic([child], is_nil(child.deleted_at)))
    |> select([child], child)
    |> Repo.all()
    |> Repo.preload(opts[:preload] || [])
  end

  def get_children(%DataStructureVersion{id: id}, opts \\ []) do
    default = Keyword.get(opts, :default)
    deleted = Keyword.get(opts, :deleted)
    confidential = Keyword.get(opts, :with_confidential)

    DataStructureRelation
    |> where([r], r.parent_id == ^id)
    |> join(:inner, [r], child in assoc(r, :child), as: :child)
    |> join(:inner, [r], relation_type in assoc(r, :relation_type), as: :relation_type)
    |> join(:inner, [child: child], ds in assoc(child, :data_structure), as: :child_ds)
    |> with_deleted(deleted, dynamic([child: c], is_nil(c.deleted_at)))
    |> with_confidential(confidential, dynamic([child_ds: ds], ds.confidential == false))
    |> relation_type_condition(
      default,
      dynamic([relation_type: rt], rt.name == "default"),
      dynamic([relation_type: rt], rt.name != "default")
    )
    |> order_by([child: c], asc: c.data_structure_id, desc: c.version)
    |> distinct([child: c], c)
    |> select([r, child: c, relation_type: rt], %{
      version: c,
      relation: r,
      relation_type: rt
    })
    |> Repo.all()
    |> select_structures(default)
  end

  def get_parents(%DataStructureVersion{id: id}, opts \\ []) do
    default = Keyword.get(opts, :default)
    deleted = Keyword.get(opts, :deleted)
    confidential = Keyword.get(opts, :with_confidential)

    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent), as: :parent)
    |> join(:inner, [r], relation_type in assoc(r, :relation_type), as: :relation_type)
    |> join(:inner, [parent: parent], parent_ds in assoc(parent, :data_structure), as: :parent_ds)
    |> with_deleted(deleted, dynamic([parent: parent], is_nil(parent.deleted_at)))
    |> relation_type_condition(
      default,
      dynamic([relation_type: rt], rt.name == "default"),
      dynamic([relation_type: rt], rt.name != "default")
    )
    |> with_confidential(confidential, dynamic([parent_ds: ds], ds.confidential == false))
    |> order_by([parent: p], asc: p.data_structure_id, desc: p.version)
    |> distinct([parent: p], p)
    |> select([r, parent: p, relation_type: rt], %{
      version: p,
      relation: r,
      relation_type: rt
    })
    |> Repo.all()
    |> select_structures(default)
  end

  def get_siblings(%DataStructureVersion{id: id}, opts \\ []) do
    default = Keyword.get(opts, :default)
    confidential = Keyword.get(opts, :with_confidential)

    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent), as: :parent)
    |> join(:inner, [r], parent_rt in assoc(r, :relation_type), as: :parent_rt)
    |> join(:inner, [parent: parent], sib_rel in DataStructureRelation,
      as: :sib_rel,
      on: parent.id == sib_rel.parent_id
    )
    |> join(:inner, [sib_rel: r], child_rt in assoc(r, :relation_type), as: :child_rt)
    |> join(:inner, [sib_rel: r], sibling in assoc(r, :child), as: :sibling)
    |> join(:inner, [sibling: s], ds in assoc(s, :data_structure), as: :sibling_ds)
    |> with_deleted(opts, dynamic([parent: p], is_nil(p.deleted_at)))
    |> with_deleted(opts, dynamic([sibling: s], is_nil(s.deleted_at)))
    |> with_confidential(confidential, dynamic([sibling_ds: ds], ds.confidential == false))
    |> relation_type_condition(
      default,
      dynamic([parent_rt: rt], rt.name == "default"),
      dynamic([parent_rt: rt], rt.name != "default")
    )
    |> relation_type_condition(
      default,
      dynamic([child_rt: rt], rt.name == "default"),
      dynamic([child_rt: rt], rt.name != "default")
    )
    |> order_by([sibling: s], asc: s.data_structure_id, desc: s.version)
    |> distinct([sibling: s], s)
    |> select([sibling: s], s)
    |> Repo.all()
    |> Repo.preload(@preload_dsv_assocs)
    |> Enum.uniq_by(& &1.data_structure_id)
  end

  defp get_relations(%DataStructureVersion{} = version, opts) do
    parents = get_parents(version, opts)
    children = get_children(version, opts)

    %{parents: parents, children: children}
  end

  defp get_relation_links(%{relations: relations}) do
    %{parents: parents, children: children} = relations

    children =
      Enum.map(children, fn %{version: dsv} = child ->
        Map.put(child, :links, get_structure_links(dsv))
      end)

    parents =
      Enum.map(parents, fn %{version: dsv} = parent ->
        Map.put(parent, :links, get_structure_links(dsv))
      end)

    relations
    |> Map.put(:children, children)
    |> Map.put(:parents, parents)
  end

  defp get_versions!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :versions) do
      %{data_structure: %{versions: versions}} -> versions
    end
  end

  defp get_grants(%DataStructureVersion{data_structure_id: id, path: path}, clauses \\ %{}) do
    ids = Enum.reduce(path, [id], fn %{"data_structure_id" => id}, acc -> [id | acc] end)

    dsv_preloader = &enriched_structure_versions(data_structure_ids: &1)

    clauses
    |> Map.put(:data_structure_ids, ids)
    |> Map.put(:preload, [:system, :data_structure, data_structure_version: dsv_preloader])
    |> Grants.list_grants()
    |> Enum.map(fn %{user_id: user_id} = grant ->
      case UserCache.get(user_id) do
        {:ok, %{} = user} -> %{grant | user: user}
        _ -> grant
      end
    end)
    |> Enum.sort_by(& &1.id)
  end

  defp get_grant(%DataStructureVersion{} = dsv, user_id) do
    dsv
    |> get_grants(%{user_id: user_id})
    # TODO: This assumes a child's external_id is longer than the parent's external_id
    |> Enum.max_by(&String.length(&1.data_structure.external_id), fn -> nil end)
  end

  defp select_structures(versions, false) do
    versions
    |> Enum.uniq_by(& &1.version.data_structure_id)
    |> Enum.map(&preload_assocs/1)
  end

  defp select_structures(versions, _not_false) do
    versions
    |> Enum.uniq_by(& &1.version.data_structure_id)
    |> Enum.map(fn %{version: version} -> version end)
    |> Repo.preload(@preload_dsv_assocs)
  end

  # These are preloaded as they are needed in views
  defp preload_assocs(%{version: v} = version, preloads \\ @preload_dsv_assocs) do
    Map.put(version, :version, Repo.preload(v, preloads))
  end

  defp get_source!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :source) do
      %{data_structure: %{source: source}} -> source
    end
  end

  defp get_metadata_versions!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :metadata_versions) do
      %{data_structure: %{metadata_versions: metadata_versions}} -> metadata_versions
    end
  end

  defp get_implementations!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: [implementations: [implementation: [:rule, :results]]]) do
      %{data_structure: %{implementations: implementations}} -> implementations
    end
  end

  defp get_tags!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv,
           data_structure: [data_structures_tags: [:data_structure_tag, :data_structure]]
         ) do
      %{data_structure: %{data_structures_tags: data_structures_tags}} -> data_structures_tags
    end
  end

  def update_changeset(%Claims{user_id: user_id}, %DataStructure{} = data_structure, %{} = params) do
    DataStructure.changeset(data_structure, params, user_id)
  end

  def update_data_structure(claims, data_structure, params, inherit) do
    changeset = update_changeset(claims, data_structure, params)
    update_data_structure(claims, changeset, inherit)
  end

  def update_data_structure(claims, changeset, inherit)

  def update_data_structure(_claims, %Changeset{valid?: false} = changeset, _),
    do: {:error, changeset}

  def update_data_structure(_claims, %Changeset{changes: %{} = changes}, _)
      when map_size(changes) == 0,
      do: {:ok, %{}}

  def update_data_structure(
        %Claims{user_id: user_id},
        %Changeset{data: %DataStructure{id: id}} = changeset,
        inherit
      ) do
    do_update_data_structure(id, changeset, inherit, user_id)
    |> tap(&on_update/1)
  end

  def update_data_structures(%Claims{user_id: user_id}, changesets, inherit)
      when is_list(changesets) do
    changesets
    |> Enum.map(fn {index, %Changeset{data: %DataStructure{id: id}} = changeset} ->
      {index, do_update_data_structure(id, changeset, inherit, user_id)}
    end)
    |> tap(fn results ->
      results
      |> Enum.reduce([], fn
        {_index, {:ok, %{updated_ids: updated_ids}}}, acc ->
          [updated_ids | acc]

        _, acc ->
          acc
      end)
      |> List.flatten()
      |> on_update
    end)
  end

  defp do_update_data_structure(id, %{changes: changes} = changeset, inherit, user_id) do
    changes
    |> Map.take([:confidential, :domain_ids])
    |> Enum.map(fn
      {key, value} ->
        {key, DataStructureQueries.update_all_query([id], key, value, user_id, inherit)}
    end)
    |> Enum.reduce(Multi.new(), fn
      {key, queryable}, multi -> Multi.update_all(multi, key, queryable, [])
    end)
    |> Multi.run(:updated_ids, &updated_ids/2)
    |> Multi.run(:audit, Audit, :data_structure_updated, [id, changeset, user_id])
    |> Repo.transaction()
  end

  defp updated_ids(_repo, %{} = changes) do
    ids =
      changes
      |> Map.take([:confidential, :domain_ids])
      |> Map.values()
      |> Enum.flat_map(fn {_, ids} -> ids end)
      |> Enum.uniq()

    {:ok, ids}
  end

  defp on_update({:ok, %{updated_ids: ids}}), do: IndexWorker.reindex(ids)
  defp on_update(_), do: :ok

  def delete_data_structure(%DataStructure{} = data_structure, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.run(:delete_versions, fn _, _ ->
      {:ok, delete_data_structure_versions(data_structure)}
    end)
    |> Multi.delete(:data_structure, data_structure)
    |> Multi.run(:audit, Audit, :data_structure_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  defp delete_data_structure_versions(%DataStructure{id: data_structure_id}) do
    DataStructureVersion
    |> where([dsv], dsv.data_structure_id == ^data_structure_id)
    |> select([dsv], dsv.data_structure_id)
    |> Repo.delete_all()
  end

  defp on_delete({:ok, %{} = res}) do
    with %{delete_versions: {_count, data_structure_ids}} <- res do
      IndexWorker.delete(data_structure_ids)
    end

    with %{descendents: %{data_structures_ids: structures_ids}} <- res do
      IndexWorker.delete(structures_ids)
    end

    {:ok, res}
  end

  defp on_delete(res), do: res

  def logical_delete_data_structure(
        %DataStructureVersion{} = data_structure_version,
        %Claims{
          user_id: user_id
        }
      ) do
    now = DateTime.utc_now()

    Multi.new()
    |> Multi.run(:descendents, fn _, _ -> get_structure_descendents(data_structure_version) end)
    |> Multi.update_all(
      :delete_dsv_descendents,
      fn changes -> delete_dsv_descendents(changes) end,
      set: [deleted_at: now]
    )
    |> Multi.update_all(
      :delete_metadata_descendents,
      fn changes -> delete_metadata_descendents(changes) end,
      set: [deleted_at: now]
    )
    |> Multi.run(:audit, Audit, :data_structure_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  def delete_dsv_descendents(%{
        descendents: %{data_structure_version_descendents: descendents_ids}
      }) do
    DataStructureVersion
    |> where([dsv], dsv.id in ^descendents_ids)
  end

  def delete_metadata_descendents(%{descendents: %{data_structures_ids: structures_ids}}) do
    StructureMetadata
    |> where([sm], sm.data_structure_id in ^structures_ids)
    |> where([sm], is_nil(sm.deleted_at))
  end

  def get_structure_descendents(data_structure_version) do
    {data_structure_version_descendents, data_structures_ids} =
      data_structure_version
      |> get_descendents()
      |> List.insert_at(0, data_structure_version)
      |> Enum.map(fn %{id: dsv_id, data_structure_id: ds_id} -> {dsv_id, ds_id} end)
      |> Enum.unzip()

    {:ok,
     %{
       data_structure_version_descendents: data_structure_version_descendents,
       data_structures_ids: data_structures_ids
     }}
  end

  def get_latest_version(target, opts \\ [])

  def get_latest_version(nil, _), do: nil

  def get_latest_version(%DataStructure{id: id}, opts) do
    get_latest_version(id, opts)
  end

  def get_latest_version(data_structure_id, opts) do
    DataStructureVersion
    |> where(data_structure_id: ^data_structure_id)
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> preload(data_structure: :source)
    |> Repo.one()
    |> enrich(opts)
  end

  def find_data_structure(%{} = clauses) do
    Repo.get_by(DataStructure, clauses)
  end

  defp get_degree(%{data_structure: %{external_id: external_id}}) do
    case GraphData.degree(external_id) do
      {:ok, degree} -> degree
      {:error, _} -> nil
    end
  end

  defp get_degree(_), do: nil

  defp get_field_degree(%{data_fields: data_fields}) do
    data_fields
    |> Repo.preload(data_structure: :system)
    |> Enum.map(&add_degree/1)
  end

  defp add_degree(dsv) do
    dsv
    |> get_degree()
    |> do_add_degree(dsv)
  end

  defp do_add_degree(nil, dsv), do: dsv
  defp do_add_degree(degree, dsv), do: Map.put(dsv, :degree, degree)

  defp get_field_links(%{data_fields: data_fields}) do
    Enum.map(data_fields, &Map.put(&1, :links, get_structure_links(&1)))
  end

  def get_structure_links(%{data_structure_id: id}) do
    case LinkCache.list("data_structure", id) do
      {:ok, links} -> links
    end
  end

  def get_structure_links(%{data_structure_id: id}, resource_type) do
    case LinkCache.list("data_structure", id, resource_type) do
      {:ok, links} -> links
    end
  end

  ## This function gets the ancestors in reverse order
  def get_ancestors(dsv, opts \\ [deleted: false]) do
    get_recursive(dsv, :parents, opts)
  end

  def get_descendents(dsv, opts \\ [deleted: false]) do
    get_recursive(dsv, :children, opts)
  end

  defp get_recursive(%DataStructureVersion{} = dsv, key, opts) do
    case Map.get(dsv, key) do
      %NotLoaded{} ->
        dsv |> Repo.preload(key) |> get_recursive(key, opts)

      [] ->
        []

      dsvs ->
        dsvs =
          case opts[:deleted] do
            false -> Enum.reject(dsvs, & &1.deleted_at)
            _ -> dsvs
          end

        dsvs ++ Enum.flat_map(dsvs, &get_recursive(&1, key, opts))
    end
  end

  def get_latest_version_by_external_id(external_id, opts \\ []) do
    DataStructureVersion
    |> with_deleted(opts, dynamic([dsv], is_nil(dsv.deleted_at)))
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> join(:inner, [data_structure], ds in assoc(data_structure, :data_structure))
    |> where([_, ds], ds.external_id == ^external_id)
    |> select_merge([_, ds], %{external_id: ds.external_id})
    |> Repo.one()
    |> enrich(opts[:enrich])
  end

  @spec get_latest_versions([non_neg_integer]) :: [DataStructureVersion.t()]
  def get_latest_versions(structure_ids) when is_list(structure_ids) do
    DataStructureVersion
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> where([dsv], dsv.data_structure_id in ^structure_ids)
    |> Repo.all()
  end

  defp with_deleted(query, opts, dynamic) when is_list(opts) do
    include_deleted = Keyword.get(opts, :deleted, true)
    with_deleted(query, include_deleted, dynamic)
  end

  defp with_deleted(query, true, _), do: query

  defp with_deleted(query, _false, dynamic) do
    where(query, ^dynamic)
  end

  defp with_confidential(query, true, _), do: query

  defp with_confidential(query, _false, dynamic) do
    where(query, ^dynamic)
  end

  defp relation_type_condition(query, false, _default, custom), do: where(query, ^custom)

  defp relation_type_condition(query, _not_false, default, _custom),
    do: where(query, ^default)

  @doc """
  Returns a Map whose keys are external ids and whose values are data
  structure ids.
  """
  def external_id_map do
    from(ds in DataStructure, select: {ds.external_id, ds.id})
    |> Repo.all()
    |> Map.new()
  end

  def create_structure_metadata(params) do
    %StructureMetadata{}
    |> StructureMetadata.changeset(params)
    |> Repo.insert()
  end

  def get_structure_metadata!(id), do: Repo.get!(StructureMetadata, id)

  def update_structure_metadata(%StructureMetadata{} = structure_metadata, params) do
    structure_metadata
    |> StructureMetadata.changeset(params)
    |> Repo.update()
  end

  def get_metadata_version(%DataStructureVersion{
        data_structure_id: structure_id,
        inserted_at: inserted_at,
        deleted_at: deleted_at
      }) do
    StructureMetadata
    |> where([sm], sm.data_structure_id == ^structure_id)
    |> where(
      [sm],
      fragment(
        "(?, COALESCE(?, statement_timestamp())) OVERLAPS (?, COALESCE(?, statement_timestamp()))",
        ^inserted_at,
        ^deleted_at,
        sm.inserted_at,
        sm.deleted_at
      )
    )
    |> order_by(desc: :version)
    |> distinct(:data_structure_id)
    |> Repo.one()
  end

  @spec template_name(any) :: any
  def template_name(%StructureNote{data_structure_id: data_structure_id}) do
    data_structure = get_data_structure!(data_structure_id)
    template_name(data_structure)
  end

  def template_name(%DataStructure{} = data_structure) do
    data_structure
    |> get_latest_version()
    |> template_name()
  end

  def template_name(%DataStructureVersion{} = dsv) do
    with %{structure_type: %{template_id: template_id}} when is_integer(template_id) <-
           Repo.preload(dsv, :structure_type),
         {:ok, %{name: name}} <- TemplateCache.get(template_id) do
      name
    else
      _ -> ""
    end
  end

  def template_name(_), do: nil

  def get_latest_metadata_by_external_ids(external_ids) do
    DataStructure
    |> where([ds], ds.external_id in ^external_ids)
    |> join(:left, [ds], m in subquery(latest_mutable_metadata_query()),
      on: m.data_structure_id == ds.id
    )
    |> select_merge([ds, m], %{latest_metadata: m})
    |> Repo.all()
  end

  @spec latest_mutable_metadata_query :: Ecto.Query.t()
  def latest_mutable_metadata_query do
    StructureMetadata
    |> distinct(:data_structure_id)
    |> order_by(asc: :data_structure_id, desc: :version)
  end

  def profile_source(
        %{data_structure: %{source: %{config: %{"job_types" => job_types}} = source}} = dsv
      ) do
    if Enum.member?(job_types, "profile") do
      Map.put(dsv, :profile_source, source)
    else
      do_profile_source(dsv, source)
    end
  end

  def profile_source(dsv), do: dsv

  defp do_profile_source(dsv, %{external_id: external_id}) when is_binary(external_id) do
    sources =
      case Sources.query_sources(%{aliases: external_id, job_types: "profile"}) do
        [_ | _] = sources -> sources
        _ -> Sources.query_sources(%{alias: external_id, job_types: "profile"})
      end

    case sources do
      [%Source{} = source | _] ->
        Map.put(dsv, :profile_source, source)

      _ ->
        dsv
    end
  end

  defp do_profile_source(dsv, _source), do: dsv

  def list_available_tags(%DataStructure{domain_ids: domain_ids}) do
    domain_ids = TaxonomyCache.reaching_domain_ids(domain_ids)
    list_data_structure_tags(domain_ids: domain_ids)
  end

  def list_data_structure_tags(params \\ %{}) do
    params
    |> data_structure_tags_query()
    |> Repo.all()
  end

  def get_data_structure_tag(params) do
    params
    |> data_structure_tags_query()
    |> Repo.one()
  end

  def get_data_structure_tag!(params) do
    params
    |> data_structure_tags_query()
    |> Repo.one!()
  end

  defp data_structure_tags_query(params) do
    params
    |> Enum.reduce(DataStructureTag, fn
      {:id, id}, q ->
        where(q, [t], t.id == ^id)

      {:domain_ids, []}, q ->
        where(q, [t], fragment("? = '{}'", t.domain_ids))

      {:domain_ids, domain_ids}, q ->
        where(q, [t], fragment("(? = '{}' OR ? && ?)", t.domain_ids, t.domain_ids, ^domain_ids))

      {:structure_count, true}, q ->
        sq =
          DataStructuresTags
          |> group_by(:data_structure_tag_id)
          |> select([g], %{
            id: g.data_structure_tag_id,
            count: count(g.data_structure_id)
          })

        q
        |> join(:left, [t], c in subquery(sq), on: c.id == t.id)
        |> select_merge([t, c], %{structure_count: fragment("coalesce(?, 0)", c.count)})
    end)
  end

  def create_data_structure_tag(attrs \\ %{}) do
    %DataStructureTag{}
    |> DataStructureTag.changeset(attrs)
    |> Repo.insert()
  end

  def update_data_structure_tag(%DataStructureTag{} = data_structure_tag, %{} = params) do
    data_structure_tag
    |> Repo.preload(:tagged_structures)
    |> DataStructureTag.changeset(params)
    |> Repo.update()
    |> on_tag_update()
  end

  def delete_data_structure_tag(%DataStructureTag{} = data_structure_tag) do
    data_structure_tag
    |> Repo.preload(:tagged_structures)
    |> Repo.delete()
    |> on_tag_delete()
  end

  def get_links_tag(%DataStructure{} = data_structure) do
    data_structure
    |> Ecto.assoc(:data_structures_tags)
    |> preload([:data_structure, :data_structure_tag])
    |> Repo.all()
  end

  def link_tag(
        %DataStructure{id: data_structure_id} = data_structure,
        %DataStructureTag{id: tag_id} = data_structure_tag,
        params,
        claims
      ) do
    data_structure_id
    |> get_link_tag_by(tag_id)
    |> case do
      nil -> create_link(data_structure, data_structure_tag, params, claims)
      %DataStructuresTags{} = tag_link -> update_link(tag_link, params, claims)
    end
  end

  def delete_link_tag(
        %DataStructure{id: data_structure_id} = structure,
        %DataStructureTag{id: tag_id},
        %Claims{user_id: user_id}
      ) do
    data_structure_id
    |> get_link_tag_by(tag_id)
    |> case do
      nil ->
        {:error, :not_found}

      %DataStructuresTags{} = tag_link ->
        Multi.new()
        |> Multi.run(:latest, fn _, _ ->
          {:ok, get_latest_version(structure, [:path])}
        end)
        |> Multi.delete(:deleted_link_tag, tag_link)
        |> Multi.run(:audit, Audit, :tag_link_deleted, [user_id])
        |> Repo.transaction()
        |> on_link_delete()
    end
  end

  def get_link_tag_by(data_structure_id, tag_id) do
    DataStructuresTags
    |> Repo.get_by(
      data_structure_tag_id: tag_id,
      data_structure_id: data_structure_id
    )
    |> Repo.preload([:data_structure, :data_structure_tag])
  end

  defp on_tag_update({:ok, %{tagged_structures: [_ | _] = structures} = tag}) do
    structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp on_tag_update(reply), do: reply

  defp on_tag_delete({:ok, %{tagged_structures: [_ | _] = structures} = tag}) do
    structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp on_tag_delete(reply), do: reply

  defp create_link(data_structure, data_structure_tag, params, %Claims{user_id: user_id}) do
    changeset =
      params
      |> DataStructuresTags.changeset()
      |> DataStructuresTags.put_data_structure(data_structure)
      |> DataStructuresTags.put_data_structure_tag(data_structure_tag)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, get_latest_version(data_structure, [:path])}
    end)
    |> Multi.insert(:linked_tag, changeset)
    |> Multi.run(:audit, Audit, :tag_linked, [user_id])
    |> Repo.transaction()
    |> on_link_insert()
  end

  defp update_link(link, params, %Claims{user_id: user_id}) do
    link = Repo.preload(link, [:data_structure_tag, :data_structure])
    changeset = DataStructuresTags.changeset(link, params)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, get_latest_version(link.data_structure, [:path])}
    end)
    |> Multi.update(:linked_tag, changeset)
    |> Multi.run(:audit, Audit, :tag_link_updated, [changeset, user_id])
    |> Repo.transaction()
  end

  defp on_link_insert({:ok, %{linked_tag: link} = multi}) do
    IndexWorker.reindex(link.data_structure_id)
    {:ok, multi}
  end

  defp on_link_insert(reply), do: reply

  defp on_link_delete({:ok, %{deleted_link_tag: link} = multi}) do
    IndexWorker.reindex(link.data_structure_id)
    {:ok, multi}
  end

  defp on_link_delete(reply), do: reply

  # Returns a data structure version enriched for indexing or rendering
  @spec enriched_structure_version!(binary() | integer(), keyword) ::
          DataStructureVersion.t()
  defp enriched_structure_version!(id, opts \\ [])

  defp enriched_structure_version!(id, opts) when is_binary(id) do
    id
    |> String.to_integer()
    |> enriched_structure_version!(opts)
  end

  defp enriched_structure_version!(id, opts) do
    opts
    |> Keyword.put(:ids, [id])
    |> enriched_structure_versions()
    |> hd()
  end

  @spec enriched_structure_versions(keyword) :: [DataStructureVersion.t()]
  def enriched_structure_versions(opts \\ []) do
    {enrich_opts, opts} = Keyword.split(opts, [:content, :filters])
    enrich = StructureVersionEnricher.enricher(enrich_opts)

    opts
    |> Map.new()
    |> DataStructureQueries.enriched_structure_versions()
    |> Repo.all()
    |> Enum.map(&enrich.(&1))
  end

  ## Dataloader

  def datasource do
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: Dataloader.default_timeout())
  end

  defp query(queryable, params) do
    Enum.reduce(params, queryable, fn
      {:deleted, false}, q -> where(q, [dsv], is_nil(dsv.deleted_at))
      {:deleted, true}, q -> where(q, [dsv], not is_nil(dsv.deleted_at))
    end)
  end
end
