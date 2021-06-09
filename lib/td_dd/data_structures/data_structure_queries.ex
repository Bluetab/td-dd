defmodule TdDd.DataStructures.DataStructureQueries do
  @moduledoc """
  Query module for enriching data structure versions
  """

  import Ecto.Query

  alias TdDd.Classifiers
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote

  @paths_by_child_id """
  SELECT child_id, c.data_structure_id as ds_id, v.data_structure_id, parent_id, 0 as level, v.name, v.version
  FROM data_structure_relations r
  JOIN data_structure_versions c on r.child_id = c.id
  JOIN data_structure_versions v on r.parent_id = v.id
  WHERE r.relation_type_id = ?
  AND c.id = ANY (?)
  UNION
  (
    SELECT p.child_id, p.ds_id, v.data_structure_id, r.parent_id, level + 1 as level, v.name, v.version
    FROM paths p
    JOIN data_structure_relations r on r.child_id = p.parent_id and r.relation_type_id = ?
    JOIN data_structure_versions v on r.parent_id = v.id
  )
  """

  @paths_by_child_structure_id """
  SELECT child_id, c.data_structure_id as ds_id, v.data_structure_id, parent_id, 0 as level, v.name, v.version
  FROM data_structure_relations r
  JOIN data_structure_versions c on r.child_id = c.id
  JOIN data_structure_versions v on r.parent_id = v.id
  WHERE r.relation_type_id = ?
  AND c.data_structure_id = ANY (?)
  UNION
  (
    SELECT p.child_id, p.ds_id, v.data_structure_id, r.parent_id, level + 1 as level, v.name, v.version
    FROM paths p
    JOIN data_structure_relations r on r.child_id = p.parent_id and r.relation_type_id = ?
    JOIN data_structure_versions v on r.parent_id = v.id
  )
  """

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

  @spec paths(map) :: Ecto.Query.t()
  def paths(%{relation_type_id: _} = params)
      when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    path_cte_params = Map.take(params, [:ids, :data_structure_ids, :relation_type_id])

    "paths"
    |> select([:ds_id, :version, :name, :data_structure_id])
    |> distinct(asc: :ds_id, desc: :level)
    |> order_by(desc: :version)
    |> subquery()
    |> recursive_ctes(true)
    |> with_path_cte("paths", path_cte_params)
    |> select([t], %{
      id: t.ds_id,
      path:
        fragment(
          "array_agg(json_build_object('data_structure_id', ?, 'name', ?))",
          t.data_structure_id,
          t.name
        )
    })
    |> group_by(:ds_id)
    |> order_by([t], asc: t.ds_id, desc: fragment("sum(? + 1)", t.version))
  end

  @spec with_path_cte(Ecto.Query.t(), binary, map) :: Ecto.Query.t()
  defp with_path_cte(query, name, params)

  defp with_path_cte(query, name, %{ids: ids, relation_type_id: rt_id}) do
    with_cte(query, ^name, as: fragment(@paths_by_child_id, ^rt_id, ^ids, ^rt_id))
  end

  defp with_path_cte(query, name, %{data_structure_ids: ids, relation_type_id: rt_id}) do
    with_cte(query, ^name, as: fragment(@paths_by_child_structure_id, ^rt_id, ^ids, ^rt_id))
  end

  @spec enriched_structure_versions(map) :: Ecto.Query.t()
  def enriched_structure_versions(%{relation_type_id: _} = params)
      when is_map_key(params, :ids) or is_map_key(params, :data_structure_ids) do
    %{
      distinct: :data_structure_id,
      preload: [data_structure: :system]
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
    |> order_by([_, sm], desc: sm.version)
    |> select_merge([_, sm], %{mutable_metadata: sm.fields})
    |> join(:left, [dsv], c in subquery(Classifiers.classes()),
      on: dsv.id == c.data_structure_version_id
    )
    |> select_merge([_, _, c], %{classes: c.classes})
    |> join(:left, [dsv], p in subquery(paths(params)), on: p.id == dsv.data_structure_id)
    |> select_merge([_, _, _, p], %{path: fragment("COALESCE(?, ARRAY[]::json[])", p.path)})
    |> join(:left, [dsv], sn in StructureNote,
    on: sn.data_structure_id == dsv.data_structure_id and sn.status == :published)
    |> select_merge([_, _, _, _, sn], %{latest_note: sn.df_content})
  end

  @spec distinct_by(Ecto.Query.t(), :id | :data_structure_id) :: Ecto.Query.t()
  defp distinct_by(query, key)

  defp distinct_by(query, :id), do: query

  defp distinct_by(query, :data_structure_id) do
    query
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
  end
end
