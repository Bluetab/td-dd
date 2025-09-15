defmodule TdDd.DataStructures.DataStructureQueries do
  @moduledoc """
  Query module for enriching data structure versions
  """

  import Ecto.Query

  alias TdCluster.Cluster.TdAi.Indices
  alias TdDd.Classifiers
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.Grants.Grant
  alias TdDd.Profiles.Profile
  alias TdDd.Repo

  @paths_by_child_id """
  SELECT dsv_id as child_id, ds_id, ancestor_ds_id as data_structure_id, ancestor_dsv_id as parent_id, ancestor_level as level, name, version
  FROM data_structures_hierarchy dsh
  JOIN data_structure_versions dsv on dsv.id = dsh.ancestor_dsv_id
  WHERE dsh.dsv_id = ANY (?) and ancestor_level > 0
  """

  @paths_by_child_structure_id """
  SELECT dsv_id as child_id, ds_id, ancestor_ds_id as data_structure_id, ancestor_dsv_id as parent_id, ancestor_level as level, name, version
  FROM data_structures_hierarchy dsh
  JOIN data_structure_versions dsv on dsv.id = dsh.ancestor_dsv_id
  WHERE dsh.ds_id = ANY (?) and ancestor_level > 0
  """

  @structure_descendents """
  select id, data_structure_id
  from data_structure_versions
  where data_structure_id = any(?)
  union (
    select v.id as id, v.data_structure_id as data_structure_id
    from data_structure_versions v
    join data_structure_relations r on v.id = r.child_id and r.relation_type_id = ?
    join descendents d on r.parent_id = d.id
  )
  """

  def children(params \\ %{grant_ids: []})

  def children(%{grant_ids: _grant_ids} = params) do
    "data_structures_hierarchy"
    |> join(:inner, [dsh], dsv_child in DataStructureVersion, on: dsh.dsv_id == dsv_child.id)
    |> join(:inner, [dsh, dsv_child], dsv_ancestor in DataStructureVersion,
      on: dsh.ancestor_dsv_id == dsv_ancestor.id
    )
    |> join(:inner, [dsh, dsv_child, dsv_ancestor], grant in Grant,
      on: dsh.ancestor_ds_id == grant.data_structure_id
    )
    |> group_by([dsh, _dsv_child, _dsv_ancestor, grant], [dsh.ancestor_ds_id, grant.id])
    |> where(
      [dsh, dsv_child, dsv_ancestor],
      is_nil(dsv_child.deleted_at) and is_nil(dsv_ancestor.deleted_at) and
        (is_nil(dsv_child.class) or dsv_child.class != "field")
    )
    |> where_grant_id_in(params)
    |> select([dsh, dsv_child, dsv_ancestor, grant], %{
      dsv_children: fragment("array_agg(?)", dsh.dsv_id),
      grant: grant
    })
    |> order_by([_, _, _, grant], grant.data_structure_id)
  end

  def children(%{data_structure_ids: data_structure_ids}) do
    "data_structures_hierarchy"
    |> join(:inner, [dsh], dsv_child in DataStructureVersion, on: dsh.dsv_id == dsv_child.id)
    |> join(:inner, [dsh, dsv_child], dsv_ancestor in DataStructureVersion,
      on: dsh.ancestor_dsv_id == dsv_ancestor.id
    )
    |> where([dsh, dsv_child, dsv_ancestor], dsh.ancestor_ds_id in ^data_structure_ids)
    |> where(
      [dsh, dsv_child, dsv_ancestor],
      is_nil(dsv_child.deleted_at) and is_nil(dsv_ancestor.deleted_at) and
        (is_nil(dsv_child.class) or dsv_child.class != "field")
    )
    |> group_by([dsh, dsv_child, dsv_ancestor], dsh.ancestor_ds_id)
    |> select([dsh, dsv_child, dsv_ancestor], %{
      ancestor_ds_id: dsh.ancestor_ds_id,
      dsv_children: fragment("array_agg(?)", dsh.dsv_id)
    })
  end

  def dsv_grant_children(opts \\ []) do
    opts_map = Enum.into(opts, %{grant_ids: []})

    "data_structures_hierarchy"
    |> join(:inner, [dsh], dsv_child in DataStructureVersion, on: dsh.dsv_id == dsv_child.id)
    |> join(:inner, [dsh, dsv_child], dsv_ancestor in DataStructureVersion,
      on: dsh.ancestor_dsv_id == dsv_ancestor.id
    )
    |> join(:inner, [dsh, dsv_child, dsv_ancestor], grant in Grant,
      on: dsh.ancestor_ds_id == grant.data_structure_id
    )
    |> where(
      [dsh, dsv_child, dsv_ancestor],
      is_nil(dsv_child.deleted_at) and is_nil(dsv_ancestor.deleted_at) and
        dsh.ancestor_level != 0 and (is_nil(dsv_child.class) or dsv_child.class != "field")
    )
    |> where_grant_id_in(opts_map)
    |> group_by([_dsh, _dsv_child, _dsv_ancestor, grant], grant.id)
    |> select([dsh, dsv_child, dsv_ancestor, grant], %{
      dsv_children: fragment("jsonb_agg(?)", dsv_child),
      grant_id: grant.id
    })
  end

  defp where_grant_id_in(query, %{grant_ids: []}), do: query

  defp where_grant_id_in(query, %{grant_ids: grant_ids}) do
    where(query, [_dsh, _dsv_child, _dsv_ancestor, grant], grant.id in ^grant_ids)
  end

  @spec data_structure_version_ids(keyword) :: Ecto.Query.t()
  def data_structure_version_ids(opts \\ []) do
    opts
    |> data_structure_versions_base()
    |> select([dsv], dsv.id)
  end

  @spec data_structure_version_embeddings(keyword) :: Ecto.Query.t()
  def data_structure_version_embeddings(opts \\ []) do
    opts
    |> data_structure_versions_base()
    |> enriched_structure_notes()
  end

  @spec data_structure_versions_with_embeddings([integer()]) :: Enumerable.t()
  def data_structure_versions_with_embeddings(data_structure_ids) do
    case Indices.list(enabled: true) do
      {:ok, [_ | _] = indices} ->
        collections = Enum.map(indices, & &1.collection_name)

        DataStructureVersion
        |> where([dsv], is_nil(dsv.deleted_at))
        |> where([dsv], dsv.data_structure_id in ^data_structure_ids)
        |> join(:inner, [dsv, re], re in RecordEmbedding,
          on: re.data_structure_version_id == dsv.id and re.collection in ^collections
        )
        |> group_by([dsv], dsv.id)
        |> select([dsv, re], %DataStructureVersion{
          dsv
          | record_embeddings: fragment("array_agg(row_to_json(?))", re)
        })
        |> Repo.stream()
        |> Stream.map(fn %DataStructureVersion{record_embeddings: record_embeddings} = dsv ->
          record_embeddings = Enum.map(record_embeddings, &RecordEmbedding.coerce/1)
          %DataStructureVersion{dsv | record_embeddings: record_embeddings}
        end)

      _other ->
        nil
    end
  end

  def data_structures_with_outdated_embeddings(collections, opts \\ []) do
    base_query =
      opts
      |> Enum.reduce(DataStructureVersion, fn
        {:limit, limit}, q -> limit(q, ^limit)
        _, q -> q
      end)
      |> where([dsv], is_nil(dsv.deleted_at))

    stale_query =
      base_query
      |> join(:left, [dsv, re], re in assoc(dsv, :record_embeddings))
      |> where([dsv, re], is_nil(re.updated_at) or re.updated_at < dsv.updated_at)
      |> select([dsv], dsv.data_structure_id)

    join_collections_set =
      from(cs in fragment("SELECT unnest(?::text[]) AS collection", ^collections),
        select: %{collection: cs.collection}
      )

    base_query
    |> join(:cross, [dsv, cs], cs in subquery(join_collections_set))
    |> join(:left, [dsv, cs, re], re in RecordEmbedding,
      on: re.data_structure_version_id == dsv.id and cs.collection == re.collection
    )
    |> where([dsv, cs, re], is_nil(re.id))
    |> select([dsv], dsv.data_structure_id)
    |> union_all(^stale_query)
    |> distinct(true)
  end

  def data_structure_versions_base(opts \\ []) do
    [deleted: false]
    |> Keyword.merge(opts)
    |> Enum.reduce(DataStructureVersion, fn
      {:deleted, false}, q -> where(q, [dsv], is_nil(dsv.deleted_at))
      {:deleted, true}, q -> where(q, [dsv], not is_nil(dsv.deleted_at))
      {:deleted, _}, q -> q
      {:data_structure_ids, ids}, q -> where(q, [dsv], dsv.data_structure_id in ^ids)
    end)
  end

  @spec profile(map) :: Ecto.Query.t()
  def profile(%{} = params)
      when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    profile_params = Map.take(params, [:ids, :data_structure_ids, :relation_type_id])

    direct_profile_versions =
      Profile
      |> join(:inner, [p], dsv in DataStructureVersion,
        on: p.data_structure_id == dsv.data_structure_id
      )
      |> where([_p, dsv], is_nil(dsv.deleted_at))
      |> where([_p, dsv], dsv.class == "field")
      |> select([_p, dsv], dsv)

    DataStructureRelation
    |> where_relation_type(profile_params)
    |> join(:inner, [r], child in subquery(direct_profile_versions), on: r.child_id == child.id)
    |> join(:inner, [r, _child], parent in DataStructureVersion, on: r.parent_id == parent.id)
    |> where([_r, _child, parent], is_nil(parent.deleted_at))
    |> select([_r, _child, parent], parent)
    |> union(^direct_profile_versions)
    |> subquery()
    |> where_ids(profile_params)
    |> select([dsv], %{id: dsv.id, with_profiling: true})
  end

  @spec tags(map) :: Ecto.Query.t()
  defp tags(%{} = params)
       when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    tags_params = Map.take(params, [:ids, :data_structure_ids])

    DataStructureVersion
    |> where_ids(tags_params)
    |> join(:inner, [dsv], h in Hierarchy, on: h.ds_id == dsv.data_structure_id, as: :h)
    |> join(:inner, [_, h], st in StructureTag,
      on:
        st.data_structure_id == h.ds_id or
          (st.inherit and st.data_structure_id == h.ancestor_ds_id)
    )
    |> join(:inner, [_, _, st], t in assoc(st, :tag))
    |> group_by([dsv], dsv.data_structure_id)
    |> select([dsv, _, _, t], %{
      data_structure_id: dsv.data_structure_id,
      tag_names: fragment("array_agg(distinct(?))", t.name)
    })
    |> subquery()
  end

  @spec paths(map) :: Ecto.Query.t()
  def paths(%{} = params)
      when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    path_cte_params = Map.take(params, [:ids, :data_structure_ids, :relation_type_id])

    "paths"
    |> select([:ds_id, :name, :data_structure_id, :level])
    |> distinct(asc: :ds_id, desc: :level)
    |> order_by(asc: :ds_id, desc: :level)
    |> subquery()
    |> with_path_cte("paths", path_cte_params)
    |> join(:inner, [t], ds in DataStructure, on: ds.id == t.data_structure_id)
    |> select([t, ds], %{
      id: t.ds_id,
      path:
        fragment(
          "array_agg(json_build_object('data_structure_id', ?, 'name', coalesce(?, ?)) order by ? desc)",
          t.data_structure_id,
          ds.alias,
          t.name,
          t.level
        )
    })
    |> group_by(:ds_id)
  end

  @spec with_path_cte(Ecto.Query.t(), binary, map) :: Ecto.Query.t()
  defp with_path_cte(query, name, params)

  defp with_path_cte(query, name, %{ids: ids}) do
    with_cte(query, ^name, as: fragment(@paths_by_child_id, ^ids))
  end

  defp with_path_cte(query, name, %{data_structure_ids: ids}) do
    with_cte(query, ^name, as: fragment(@paths_by_child_structure_id, ^ids))
  end

  defp where_relation_type(query, %{} = params) do
    relation_type_id = Map.get(params, :relation_type_id, RelationTypes.default_id!())
    where(query, [r], r.relation_type_id == ^relation_type_id)
  end

  defp where_ids(query, %{data_structure_ids: ids}) do
    where(query, [dsv], dsv.data_structure_id in ^ids)
  end

  defp where_ids(query, %{ids: ids}) do
    where(query, [dsv], dsv.id in ^ids)
  end

  @spec enriched_structure_versions(map) :: Ecto.Query.t()
  def enriched_structure_versions(%{} = params)
      when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    %{
      distinct: :data_structure_id
      # preload: [data_structure: [:system, :published_note]]
    }
    |> Map.merge(params)
    |> Enum.reduce(DataStructureVersion, fn
      {:distinct, d}, q -> distinct_by(q, d)
      {:preload, preloads}, q -> preload(q, ^preloads)
      {:id, id}, q -> where(q, [dsv], dsv.id == ^id)
      {:ids, ids}, q -> where(q, [dsv], dsv.id in ^ids)
      {:data_structure_ids, ids}, q -> where(q, [dsv], dsv.data_structure_id in ^ids)
      {:relation_type_id, _}, q -> q
    end)
    |> enriched_structure_notes()
    |> join(:left, [dsv], sm in StructureMetadata,
      as: :metadata,
      on:
        sm.data_structure_id == dsv.data_structure_id and
          fragment(
            "(?, COALESCE(?, CURRENT_TIMESTAMP)) OVERLAPS (?, COALESCE(?, CURRENT_TIMESTAMP))",
            dsv.inserted_at,
            dsv.deleted_at,
            sm.inserted_at,
            sm.deleted_at
          )
    )
    |> order_by([metadata: sm], desc: sm.version)
    |> select_merge([metadata: sm], %{mutable_metadata: sm.fields})
    |> join(:left, [dsv], c in subquery(Classifiers.classes()),
      as: :classes,
      on: dsv.id == c.data_structure_version_id
    )
    |> select_merge([classes: c], %{classes: c.classes})
    |> join(:left, [dsv], p in subquery(paths(params)),
      as: :paths,
      on: p.id == dsv.data_structure_id
    )
    |> select_merge([paths: p], %{path: fragment("COALESCE(?, ARRAY[]::json[])", p.path)})
    |> join(:left, [dsv], pv in subquery(profile(params)), as: :profiles, on: dsv.id == pv.id)
    |> select_merge([profiles: pv], %{
      with_profiling: fragment("COALESCE(?, false)", pv.with_profiling)
    })
    |> join(:left, [dsv], t in subquery(tags(params)),
      as: :tags,
      on: dsv.data_structure_id == t.data_structure_id
    )
    |> select_merge([tags: t], %{tag_names: t.tag_names})
  end

  def enriched_structure_notes(query) do
    query
    |> join(:left, [dsv], ds in assoc(dsv, :data_structure), as: :ds)
    |> join(:left, [ds: ds], s in assoc(ds, :system), as: :sys)
    |> join(:left, [ds: ds], pn in assoc(ds, :published_note), as: :pn)
    |> join(:left, [ds: ds], dn in assoc(ds, :draft_note), as: :dn)
    |> join(:left, [ds: ds], pan in assoc(ds, :pending_approval_note), as: :pan)
    |> join(:left, [ds: ds], rn in assoc(ds, :rejected_note), as: :rn)
    |> select_merge([ds: ds, sys: sys, pn: pn, dn: dn, pan: pan, rn: rn], %{
      data_structure: %{
        ds
        | system: sys,
          published_note: pn,
          draft_note: dn,
          pending_approval_note: pan,
          rejected_note: rn
      }
    })
  end

  @spec distinct_by(Ecto.Query.t(), :id | :data_structure_id) :: Ecto.Query.t()
  defp distinct_by(query, key)

  defp distinct_by(query, :id), do: query

  defp distinct_by(query, :data_structure_id) do
    query
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
  end

  def update_all_query(ids, field, value, last_change_by, recursive)
      when is_list(ids) and field in [:confidential, :domain_ids] do
    set = [
      {field, value},
      {:last_change_by, last_change_by},
      {:updated_at, DateTime.utc_now()}
    ]

    DataStructure
    |> recursive(ids, recursive)
    |> where([ds], field(ds, ^field) != ^value)
    |> select([ds], ds.id)
    |> update(set: ^set)
  end

  defp recursive(query, data_structure_ids, true) do
    descendent_ids = select_recursive(data_structure_ids)
    where(query, [ds], ds.id in subquery(descendent_ids))
  end

  defp recursive(query, data_structure_ids, false) do
    where(query, [ds], ds.id in ^data_structure_ids)
  end

  defp select_recursive(data_structure_ids) do
    relation_type_id = RelationTypes.default_id!()

    "descendents"
    |> recursive_ctes(true)
    |> with_cte("descendents",
      as: fragment(@structure_descendents, ^data_structure_ids, ^relation_type_id)
    )
    |> select([d], d.data_structure_id)
  end

  def data_structures_query(enumerable) do
    Enum.reduce(enumerable, DataStructure, fn
      {:deleted, false}, q ->
        join(q, :inner, [ds], u in assoc(ds, :current_version))

      {:external_id, external_id}, q ->
        where(q, [ds], ds.external_id in ^List.wrap(external_id))

      {:ids, ids}, q ->
        where(q, [ds], ds.id in ^ids)

      {:domain_ids, domain_ids}, q ->
        where(q, [ds], fragment("? && ?", ds.domain_ids, ^domain_ids))

      {:system_ids, system_ids}, q ->
        where(q, [ds], ds.system_id in ^system_ids)

      {:data_structure_types, ds_types}, q ->
        q
        |> join(:inner, [ds], u in assoc(ds, :current_version), as: :version_for_types)
        |> where([version_for_types: v], v.type in ^ds_types)

      {:has_note, has_note}, q ->
        structure_notes =
          StructureNote
          |> group_by([sn], sn.data_structure_id)
          |> select([sn], %{data_structure_id: sn.data_structure_id})

        q
        |> join(:left, [ds], sn in subquery(structure_notes),
          as: :has_note,
          on: ds.id == sn.data_structure_id
        )
        |> where([has_note: sn], is_nil(sn.data_structure_id) != ^has_note)

      {:note_statuses, statuses}, q ->
        latest_structure_note =
          select(StructureNote, [sn], %{
            data_structure_id: sn.data_structure_id,
            status: sn.status,
            row_number:
              fragment(
                "ROW_NUMBER() OVER (PARTITION BY ? ORDER BY ? DESC)",
                sn.data_structure_id,
                sn.version
              )
          })

        q
        |> join(:left, [ds], sn in subquery(latest_structure_note),
          as: :latest_structure_note,
          on: ds.id == sn.data_structure_id and sn.row_number == 1
        )
        |> where([latest_structure_note: sn], sn.status in ^statuses)

      {:limit, 0}, q ->
        q

      {:limit, limit}, q ->
        limit(q, ^limit)

      {:lineage, true}, q ->
        having_units(q)

      {:min_id, id}, q ->
        where(q, [ds], ds.id >= ^id)

      {:order_by, "id"}, q ->
        order_by(q, :id)

      {:preload, preloads}, q ->
        preload(q, ^preloads)

      {:since, since}, q ->
        where(q, [ds], ds.updated_at >= ^since)
    end)
  end

  defp having_units(queryable) do
    queryable
    |> join(:inner, [ds], u in assoc(ds, :units), as: :units)
    |> where([units: u], is_nil(u.deleted_at))
  end
end
