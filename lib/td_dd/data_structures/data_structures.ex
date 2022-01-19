defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdCx.Sources
  alias TdCx.Sources.Source
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Ancestry
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
  alias TdDd.Search.StructureEnricher
  alias TdDfLib.Format

  # Data structure version associations preloaded for some views
  @preload_dsv_assocs [:classifications, data_structure: :system]

  def list_data_structures(clauses \\ %{}, preload \\ [:system]) do
    clauses
    |> Enum.reduce(DataStructure, fn
      {:external_id, external_ids}, q when is_list(external_ids) ->
        where(q, [ds], ds.external_id in ^external_ids)

      {:external_id, external_id}, q ->
        where(q, [ds], ds.external_id == ^external_id)

      {:domain_id, domain_id}, q when is_list(domain_id) ->
        where(q, [ds], ds.domain_id in ^domain_id)

      {:domain_id, domain_id}, q ->
        where(q, [ds], ds.domain_id == ^domain_id)

      {:id, {:in, ids}}, q ->
        where(q, [ds], ds.id in ^ids)
    end)
    |> join(:left, [ds], sn in StructureNote,
      on: sn.data_structure_id == ds.id and sn.status == :published
    )
    |> select_merge([_, sn], %{latest_note: sn.df_content})
    |> preload(^preload)
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
        preload: if(Enum.member?(opts, :profile), do: [data_structure: :profile], else: []),
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
  end

  defp enrich(%{} = target, opts, key, fun) do
    target_key = get_target_key(key)

    case Enum.member?(opts, key) do
      false -> target
      true -> Map.put(target, target_key, fun.(target))
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
    |> where([child], child.class == "field")
    |> join(:inner, [child], child in assoc(child, :data_structure))
    |> with_confidential(
      Keyword.get(opts, :with_confidential),
      dynamic([_child, _parent, child_ds], child_ds.confidential == false)
    )
    |> with_deleted(opts, dynamic([child], is_nil(child.deleted_at)))
    |> select([child], child)
    |> Repo.all()
    |> Repo.preload(opts[:preload] || [])
  end

  def get_children(%DataStructureVersion{id: id}, opts \\ []) do
    DataStructureRelation
    |> where([r], r.parent_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :child))
    |> join(:inner, [r, _parent, _], r in assoc(r, :relation_type))
    |> join(:inner, [_r, child, _], child in assoc(child, :data_structure))
    |> with_deleted(
      Keyword.get(opts, :deleted),
      dynamic([_, parent, _], is_nil(parent.deleted_at))
    )
    |> with_confidential(
      Keyword.get(opts, :with_confidential),
      dynamic([_, _child, _, ds_child], ds_child.confidential == false)
    )
    |> relation_type_condition(
      Keyword.get(opts, :default),
      dynamic([_, _child, relation_type, _], relation_type.name == "default"),
      dynamic([_, _child, relation_type, _], relation_type.name != "default")
    )
    |> order_by([_, child, _, _], asc: child.data_structure_id, desc: child.version)
    |> distinct([_, child, _, _], child)
    |> select([r, child, relation_type, _], %{
      version: child,
      relation: r,
      relation_type: relation_type
    })
    |> Repo.all()
    |> select_structures(Keyword.get(opts, :default))
  end

  def get_parents(%DataStructureVersion{id: id}, opts \\ []) do
    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent))
    |> join(:inner, [r, _parent], relation_type in assoc(r, :relation_type))
    |> join(:inner, [_r, parent, _relation_type], parent in assoc(parent, :data_structure))
    |> with_deleted(
      Keyword.get(opts, :deleted),
      dynamic([_, parent, _, _], is_nil(parent.deleted_at))
    )
    |> relation_type_condition(
      Keyword.get(opts, :default),
      dynamic([_, _parent, relation_type, _], relation_type.name == "default"),
      dynamic([_, _parent, relation_type, _], relation_type.name != "default")
    )
    |> with_confidential(
      Keyword.get(opts, :with_confidential),
      dynamic([_, _parent, _relation_type, parent_ds], parent_ds.confidential == false)
    )
    |> order_by([_, parent, _, _], asc: parent.data_structure_id, desc: parent.version)
    |> distinct([_, parent, _, _], parent)
    |> select([r, parent, relation_type], %{
      version: parent,
      relation: r,
      relation_type: relation_type
    })
    |> Repo.all()
    |> select_structures(Keyword.get(opts, :default))
  end

  def get_siblings(%DataStructureVersion{id: id}, opts \\ []) do
    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent))
    |> join(:inner, [r, _parent], parent_rt in assoc(r, :relation_type))
    |> join(:inner, [_r, parent, _parent_rt, r_c], r_c in DataStructureRelation,
      on: parent.id == r_c.parent_id
    )
    |> join(:inner, [_r, _parent, _parent_rt, r_c], child_rt in assoc(r_c, :relation_type))
    |> join(:inner, [_r, _parent, _parent_rt, r_c, _child_rt], sibling in assoc(r_c, :child))
    |> join(
      :inner,
      [_r, _parent, _parent_rt, _r_c, _child_rt, sibling],
      sibling in assoc(sibling, :data_structure)
    )
    |> with_deleted(
      opts,
      dynamic(
        [_r, parent, _parent_rt, _r_c, _child_rt, _sibling, _sibling_ds],
        is_nil(parent.deleted_at)
      )
    )
    |> with_deleted(
      opts,
      dynamic(
        [_r, parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds],
        is_nil(sibling.deleted_at)
      )
    )
    |> with_confidential(
      Keyword.get(opts, :with_confidential),
      dynamic(
        [_r, _parent, _parent_rt, _r_c, _child_rt, _sibling, sibling_ds],
        sibling_ds.confidential == false
      )
    )
    |> relation_type_condition(
      Keyword.get(opts, :default),
      dynamic(
        [_r, _parent, parent_rt, _r_c, _child_rt, _sibling, _sibling_ds],
        parent_rt.name == "default"
      ),
      dynamic(
        [_r, _parent, parent_rt, _r_c, _child_rt, _sibling, _sibling_ds],
        parent_rt.name != "default"
      )
    )
    |> relation_type_condition(
      Keyword.get(opts, :default),
      dynamic(
        [_r, _parent, _parent_rt, _r_c, child_rt, _sibling, _sibling_ds],
        child_rt.name == "default"
      ),
      dynamic(
        [_r, _parent, _parent_rt, _r_c, child_rt, _sibling, _sibling_ds],
        child_rt.name != "default"
      )
    )
    |> order_by([_r, _parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds],
      asc: sibling.data_structure_id,
      desc: sibling.version
    )
    |> distinct([_r, _parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds], sibling)
    |> select([_r, _parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds], sibling)
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
    |> Enum.map(& &1.version)
    |> Enum.uniq_by(& &1.data_structure_id)
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

  defp get_tags!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv,
           data_structure: [data_structures_tags: [:data_structure_tag, :data_structure]]
         ) do
      %{data_structure: %{data_structures_tags: data_structures_tags}} -> data_structures_tags
    end
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value}, claims)
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(%DataStructure{} = data_structure, %{} = params, %Claims{
        user_id: user_id
      }) do
    changeset = DataStructure.update_changeset(data_structure, params)

    Multi.new()
    |> Multi.update(:data_structure, changeset)
    |> Multi.run(:audit, Audit, :data_structure_updated, [changeset, user_id])
    |> Multi.run(:updated_children_count, fn _repo, %{data_structure: updated_data_structure} ->
      maybe_update_children_domain_ids(updated_data_structure, data_structure)
    end)
    |> Repo.transaction()
    |> on_update()
  end

  defp maybe_update_children_domain_ids(
         %{domain_id: new_domain_id, external_id: parent_external_id},
         %{domain_id: old_domain_id}
       )
       when old_domain_id != new_domain_id do
    children_ids = Ancestry.get_descendent_ids(parent_external_id)

    {count, _} =
      from(ds in DataStructure,
        where: ds.id in ^children_ids,
        update: [set: [domain_id: ^new_domain_id]]
      )
      |> Repo.update_all([])

    IndexWorker.reindex(children_ids)
    {:ok, count}
  end

  defp maybe_update_children_domain_ids(_updated, _new) do
    {:ok, 0}
  end

  defp on_update(res, opts \\ []) do
    case opts[:is_bulk_update] == true do
      false -> on_update_structure(res)
      _ -> res
    end
  end

  defp on_update_structure({:ok, %StructureNote{status: :published, data_structure_id: id}} = res) do
    IndexWorker.reindex(id)
    res
  end

  defp on_update_structure({:ok, %StructureNote{}} = res), do: res

  defp on_update_structure({:ok, %{} = res}) do
    with %{data_structure: %{id: id}} <- res do
      IndexWorker.reindex(id)
    end

    {:ok, res}
  end

  defp on_update_structure(res), do: res

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

  def put_domain_id(data, %{} = domain_map, domain) when is_binary(domain) do
    case Map.get(domain_map, domain) do
      nil -> data
      domain_id -> Map.put(data, "domain_id", domain_id)
    end
  end

  def put_domain_id(data, _domain_map, _domain), do: data

  def put_domain_id(%{"domain_id" => domain_id} = data, external_ids)
      when is_nil(domain_id) or domain_id == "" do
    with_domain_id(data, external_ids)
  end

  def put_domain_id(%{"domain_id" => _} = data, _external_ids), do: data

  def put_domain_id(data, external_ids) do
    with_domain_id(data, external_ids)
  end

  defp with_domain_id(data, external_ids) do
    case get_domain_id(data, external_ids) do
      nil -> data
      domain_id -> Map.put(data, "domain_id", domain_id)
    end
  end

  defp get_domain_id(%{"domain_external_id" => external_id}, %{} = external_ids)
       when not is_nil(external_id) and external_id != "" do
    Map.get(external_ids, external_id)
  end

  defp get_domain_id(%{"ou" => ou}, %{} = external_ids)
       when not is_nil(ou) and ou != "" do
    Map.get(external_ids, ou)
  end

  defp get_domain_id(_data, _external_id), do: nil

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

  def list_data_structure_tags(opts \\ []) do
    DataStructureTag
    |> Repo.all()
    |> Repo.preload(opts[:preload] || [])
  end

  def get_data_structure_tag!(id, opts \\ []) do
    DataStructureTag
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
  end

  def create_data_structure_tag(attrs \\ %{}) do
    %DataStructureTag{}
    |> DataStructureTag.changeset(attrs)
    |> Repo.insert()
  end

  def update_data_structure_tag(%DataStructureTag{} = data_structure_tag, attrs) do
    data_structure_tag
    |> DataStructureTag.changeset(attrs)
    |> Repo.update()
    |> on_tag_update()
  end

  def delete_data_structure_tag(%DataStructureTag{} = data_structure_tag) do
    data_structure_tag
    |> Repo.delete()
    |> on_tag_delete(Map.get(data_structure_tag, :tagged_structures))
  end

  def get_links_tag(%DataStructure{data_structures_tags: tags})
      when is_list(tags) do
    tags
  end

  def get_links_tag(%DataStructure{} = data_structure) do
    data_structure
    |> Repo.preload(data_structures_tags: [:data_structure, :data_structure_tag])
    |> Map.get(:data_structures_tags)
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

  defp on_tag_delete({:ok, tag}, [_ | _] = structures) do
    structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp on_tag_delete(reply, _), do: reply

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
    {content_opt, opts} = Keyword.pop(opts, :content)

    opts
    |> Map.new()
    |> DataStructureQueries.enriched_structure_versions()
    |> Repo.all()
    |> Enum.map(fn %{data_structure: structure, type: type, latest_note: latest_note} = dsv ->
      %{
        dsv
        | data_structure:
            StructureEnricher.enrich(
              Map.put(structure, :latest_note, latest_note),
              type,
              content_opt
            )
      }
    end)
  end

  @doc """
  Returns the list of structure_notes.

  ## Examples

      iex> list_structure_notes()
      [%StructureNote{}, ...]

  """
  def list_structure_notes do
    Repo.all(StructureNote)
  end

  def list_structure_notes(%{} = filters) do
    filters
    |> Enum.reduce(StructureNote, &add_filter/2)
    |> Repo.all()
    |> Repo.preload(:data_structure)
  end

  def list_structure_notes(data_structure_id) do
    StructureNote
    |> where(data_structure_id: ^data_structure_id)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def list_structure_notes(data_structure_id, statuses) when is_list(statuses) do
    StructureNote
    |> where(data_structure_id: ^data_structure_id)
    |> where([sn], sn.status in ^statuses)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def list_structure_notes(data_structure_id, status),
    do: list_structure_notes(data_structure_id, [status])

  defp add_filter({"status", status}, query), do: where(query, status: ^status)

  defp add_filter({"updated_at", updated_at}, query),
    do: where(query, [sn], sn.updated_at >= ^updated_at)

  defp add_filter({"system_id", system_id}, query) do
    query
    |> join(:inner, [sn], ds in assoc(sn, :data_structure))
    |> where([_sn, ds], ds.system_id == ^system_id)
  end

  defp add_filter(_, query), do: query

  @doc """
  Gets a single structure_note.

  Raises `Ecto.NoResultsError` if the Structure note does not exist.

  ## Examples

      iex> get_structure_note!(123)
      %StructureNote{}

      iex> get_structure_note!(456)
      ** (Ecto.NoResultsError)

  """
  def get_structure_note!(id), do: Repo.get!(StructureNote, id)

  def latest_structure_note_query(query, data_structure_id) do
    query
    |> where(data_structure_id: ^data_structure_id)
    |> order_by(desc: :version)
    |> limit(1)
  end

  def get_latest_structure_note(data_structure_id, status) do
    StructureNote
    |> where(status: ^status)
    |> latest_structure_note_query(data_structure_id)
    |> Repo.one()
  end

  def get_latest_structure_note(data_structure_id) do
    StructureNote
    |> latest_structure_note_query(data_structure_id)
    |> Repo.one()
    |> Repo.preload(:data_structure)
  end

  @doc """
  Creates a structure_note.

  ## Examples

      iex> create_structure_note(%{field: value}, %{}, user_id)
      {:ok, %StructureNote{}}

      iex> create_structure_note(%{field: bad_value}, %{}, user_id)
      {:error, %Ecto.Changeset{}}

  """
  def create_structure_note(data_structure, attrs, user_id) do
    changeset =
      StructureNote.create_changeset(
        %StructureNote{},
        data_structure,
        attrs
      )

    Multi.new()
    |> Multi.insert(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note)}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
    |> on_update()
  end

  @spec bulk_create_structure_note(
          map,
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any},
          nil | %{:data_structure => any, :df_content => any, optional(any) => any},
          any
        ) :: any
  def bulk_create_structure_note(data_structure, attrs, nil, user_id) do
    bulk_create_structure_note(data_structure, attrs, %StructureNote{}, user_id)
  end

  def bulk_create_structure_note(data_structure, attrs, latest_note, user_id) do
    changeset =
      StructureNote.bulk_create_changeset(
        latest_note,
        data_structure,
        attrs
      )

    Multi.new()
    |> Multi.insert(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note)}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
    |> on_update()
  end

  @doc """
  Updates a structure_note with bulk_update behaviour.

  ## Examples

      iex> bulk_update_structure_note(structure_note, %{field: new_value}, user_id)
      {:ok, %StructureNote{}}

      iex> bulk_update_structure_note(structure_note, %{field: bad_value}, user_id)
      {:error, %Ecto.Changeset{}}

  """

  def bulk_update_structure_note(%StructureNote{} = structure_note, attrs, user_id) do
    structure_note = Repo.preload(structure_note, :data_structure)
    changeset = StructureNote.bulk_update_changeset(structure_note, attrs)

    if changeset.changes == %{} do
      {:ok, structure_note}
    else
      Multi.new()
      |> Multi.update(:structure_note, changeset)
      |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
      |> Repo.transaction()
      |> case do
        {:ok, res} -> {:ok, Map.get(res, :structure_note)}
        {:error, :structure_note, err, _} -> {:error, err}
        err -> err
      end
      |> on_update()
    end
  end

  @doc """
  Updates a structure_note.

  ## Examples

      iex> update_structure_note(structure_note, %{field: new_value}, user_id)
      {:ok, %StructureNote{}}

      iex> update_structure_note(structure_note, %{field: bad_value}, user_id)
      {:error, %Ecto.Changeset{}}

  """

  def update_structure_note(_structure_note, _attrs, _user_id, opts \\ [])

  def update_structure_note(
        %StructureNote{} = structure_note,
        %{"status" => status} = attrs,
        user_id,
        opts
      )
      when status in [
             "published",
             "pending_approval",
             "rejected",
             "published",
             "versioned",
             "draft",
             "deprecated"
           ] do
    changeset = StructureNote.changeset(structure_note, attrs)

    %{data_structure: data_structure} =
      structure_note =
      structure_note
      |> Repo.preload(:data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, get_latest_version(data_structure, [:path])}
    end)
    |> Multi.run(:structure_note, fn _, _ ->
      {:ok, structure_note}
    end)
    |> Multi.update(:structure_note_update, changeset)
    |> Multi.run(:audit, Audit, :structure_note_status_updated, [status, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note_update)}
      {:error, :structure_note_update, err, _} -> {:error, err}
      err -> err
    end
    |> on_update(opts)
  end

  def update_structure_note(%StructureNote{} = structure_note, attrs, user_id, opts) do
    structure_note = Repo.preload(structure_note, :data_structure)
    changeset = StructureNote.changeset(structure_note, attrs)

    Multi.new()
    |> Multi.update(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note)}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
    |> on_update(opts)
  end

  @doc """
  Deletes a structure_note.

  ## Examples

      iex> delete_structure_note(structure_note, user_id)
      {:ok, %StructureNote{}}

      iex> delete_structure_note(structure_note, user_id)
      {:error, %Ecto.Changeset{}}

  """
  def delete_structure_note(
        %StructureNote{} = structure_note,
        user_id
      ) do
    %{data_structure: data_structure} =
      structure_note =
      structure_note
      |> Repo.preload(:data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, get_latest_version(data_structure, [:path])}
    end)
    |> Multi.delete(:structure_note, structure_note)
    |> Multi.run(:audit, Audit, :structure_note_deleted, [user_id])
    |> Repo.transaction()
    |> case do
      {:ok, %{structure_note: structure_note}} ->
        {:ok, structure_note}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking structure_note changes.

  ## Examples

      iex> change_structure_note(structure_note)
      %Ecto.Changeset{data: %StructureNote{}}

  """
  def change_structure_note(%StructureNote{} = structure_note, attrs \\ %{}) do
    StructureNote.changeset(structure_note, attrs)
  end

  ## Dataloader

  def datasource do
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: Dataloader.default_timeout())
  end

  defp query(queryable, _params) do
    queryable
  end
end
