defmodule TdDd.DataStructures.DataStructureQueries do
  @moduledoc """
  Query module for enriching data structure versions
  """

  import Ecto.Query

  alias TdDd.Classifiers
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Profiles.Profile

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

  @dsv_children_without_fields """
  select ancestor_ds_id as dsid, count(dsv_id), ARRAY_AGG (dsv_id) from
  (
    SELECT dsh.dsv_id, ancestor_ds_id FROM data_structures_hierarchy dsh
    join (select id as dsv_id, version as child_version, deleted_at as child_deleted_at, class as child_class from data_structure_versions) dsvc on dsh.dsv_id = dsvc.dsv_id
    join (select id as dsv_id, version as ancestor_version, deleted_at as ancestor_deleted_at from data_structure_versions) dsva on dsh.ancestor_dsv_id = dsva.dsv_id
    where ancestor_deleted_at is null and child_deleted_at is null and (child_class is null or child_class != 'field')
  ) as foo
  group by ancestor_ds_id
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

  def children(opts \\ []) do
    opts_map = Enum.into(opts, %{grant_ids: []})

    TdDd.Grants.Grant
    |> with_cte("children", as: fragment(@dsv_children_without_fields))
    |> join(:inner, [g], c in "children", on: c.dsid == g.data_structure_id)
    |> select([g, c], %{grant: g, dsv_children: c.array_agg})
    |> where_grant_ids(opts_map)
  end

  defp where_grant_ids(query, %{grant_ids: []}) do
    query
  end

  defp where_grant_ids(query, %{grant_ids: grant_ids}) do
    where(query, [g], g.id in ^grant_ids)
  end

  @spec data_structure_version_ids(keyword) :: Ecto.Query.t()
  def data_structure_version_ids(opts \\ []) do
    [deleted: false]
    |> Keyword.merge(opts)
    |> Enum.reduce(DataStructureVersion, fn
      {:deleted, false}, q -> where(q, [dsv], is_nil(dsv.deleted_at))
      {:deleted, true}, q -> where(q, [dsv], not is_nil(dsv.deleted_at))
      {:deleted, _}, q -> q
      {:data_structure_ids, ids}, q -> where(q, [dsv], dsv.data_structure_id in ^ids)
    end)
    |> select([dsv], dsv.id)
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

  @spec paths(map) :: Ecto.Query.t()
  def paths(%{} = params)
      when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    path_cte_params = Map.take(params, [:ids, :data_structure_ids, :relation_type_id])

    "paths"
    |> select([:ds_id, :name, :data_structure_id])
    |> distinct(asc: :ds_id, desc: :level)
    |> order_by(desc: :parent_id)
    |> subquery()
    |> with_path_cte("paths", path_cte_params)
    |> join(:left, [t], n in subquery(published_note()),
      on: t.data_structure_id == n.data_structure_id
    )
    |> select([t, n], %{
      id: t.ds_id,
      path:
        fragment(
          "array_agg(json_build_object('data_structure_id', ?, 'name', coalesce(?->>'alias', ?)))",
          t.data_structure_id,
          n.content,
          t.name
        )
    })
    |> group_by(:ds_id)
    |> order_by([t], asc: t.ds_id)
  end

  defp published_note do
    StructureNote
    |> select([sn], %{
      data_structure_id: sn.data_structure_id,
      content: sn.df_content,
      status: sn.status
    })
    |> where([sn], sn.status == :published)
    |> where([sn], not is_nil(sn.df_content))
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
      distinct: :data_structure_id,
      preload: [data_structure: [:system, :tags, :published_note]]
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
    |> join(:left, [dsv], n in assoc(dsv, :published_note), as: :notes)
    |> select_merge([notes: n], %{alias: n.df_content["alias"]})
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
      {:deleted, false}, q -> join(q, :inner, [ds], u in assoc(ds, :current_version))
      {:external_id, external_id}, q -> where(q, [ds], ds.external_id in ^List.wrap(external_id))
      {:ids, ids}, q -> where(q, [ds], ds.id in ^ids)
      {:limit, limit}, q -> limit(q, ^limit)
      {:lineage, true}, q -> having_units(q)
      {:min_id, id}, q -> where(q, [ds], ds.id >= ^id)
      {:order_by, "id"}, q -> order_by(q, :id)
      {:preload, preloads}, q -> preload(q, ^preloads)
      {:since, since}, q -> where(q, [ds], ds.updated_at >= ^since)
    end)
  end

  defp having_units(queryable) do
    queryable
    |> join(:inner, [ds], u in assoc(ds, :units), as: :units)
    |> where([units: u], is_nil(u.deleted_at))
  end
end
