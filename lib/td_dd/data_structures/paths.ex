defmodule TdDd.DataStructures.Paths do
  @moduledoc """
  Use a recursive CTE to resolve data structure paths.
  """

  alias TdDd.DataStructures.Paths.Path

  import Ecto.Query

  @all_paths """
  SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY[v.name] AS names, ARRAY[v.data_structure_id] AS structure_ids, ARRAY[ds.external_id] AS external_ids, v.version + 1 AS v_sum
  FROM data_structure_versions v
  INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
  LEFT OUTER JOIN data_structure_relations AS r ON r.child_id = v.id
  LEFT OUTER JOIN relation_types t ON t.id = r.relation_type_id AND t.name = 'default'
  WHERE r.id IS NULL
  UNION (
    SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY_PREPEND(v.name, p0.names)::varchar(255)[] AS names, ARRAY_PREPEND(v.data_structure_id, p0.structure_ids)::bigint[] AS structure_ids, ARRAY_PREPEND(ds.external_id, p0.external_ids)::text[] AS external_ids, p0.v_sum + v.version + 1 AS v_sum
    FROM data_structure_versions v
    INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
    INNER JOIN data_structure_relations as r ON r.child_id = v.id
    INNER JOIN relation_types t ON t.id = r.relation_type_id AND t.name = 'default'
    INNER JOIN paths p0 on p0.id = r.parent_id
  )
  """

  @paths_by_structure_id """
  SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY[v.name] AS names, ARRAY[v.data_structure_id] AS structure_ids, ARRAY[ds.external_id] AS external_ids, v.version + 1 AS v_sum
  FROM data_structure_versions v
  INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
  WHERE ds.id = ?
  UNION ALL (
    SELECT v.id AS id, p0.vid AS vid, v.name AS name, ARRAY_APPEND(p0.names, v.name)::varchar(255)[] AS names, ARRAY_APPEND(p0.structure_ids, v.data_structure_id)::bigint[] AS structure_ids, ARRAY_APPEND(p0.external_ids, ds.external_id)::varchar(255)[] AS external_ids, p0.v_sum + v.version + 1 AS v_sum
    FROM data_structure_versions v
    INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
    INNER JOIN data_structure_relations AS r ON r.parent_id = v.id
    INNER JOIN relation_types AS t ON t.id = r.relation_type_id AND t.name = 'default'
    INNER JOIN paths AS p0 ON p0.id = r.child_id
  )
  """

  @paths_by_structure_id_and_version """
  SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY[v.name] AS names, ARRAY[v.data_structure_id] AS structure_ids, ARRAY[ds.external_id] AS external_ids, v.version + 1 AS v_sum
  FROM data_structure_versions v
  INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
  WHERE ds.id = ?
  AND v.version = ?
  UNION ALL (
    SELECT v.id AS id, p0.vid AS vid, v.name AS name, ARRAY_APPEND(p0.names, v.name)::varchar(255)[] AS names, ARRAY_APPEND(p0.structure_ids, v.data_structure_id)::bigint[] AS structure_ids, ARRAY_APPEND(p0.external_ids, ds.external_id)::varchar(255)[] AS external_ids, p0.v_sum + v.version + 1 AS v_sum
    FROM data_structure_versions v
    INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
    INNER JOIN data_structure_relations AS r ON r.parent_id = v.id
    INNER JOIN relation_types AS t ON t.id = r.relation_type_id AND t.name = 'default'
    INNER JOIN paths AS p0 ON p0.id = r.child_id
  )
  """

  @paths_by_version_id """
  SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY[v.name] AS names, ARRAY[v.data_structure_id] AS structure_ids, ARRAY[ds.external_id] AS external_ids, v.version + 1 AS v_sum
  FROM data_structure_versions v
  INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
  WHERE v.id = ?
  UNION ALL (
    SELECT v.id AS id, p0.vid AS vid, v.name AS name, ARRAY_APPEND(p0.names, v.name)::varchar(255)[] AS names, ARRAY_APPEND(p0.structure_ids, v.data_structure_id)::bigint[] AS structure_ids, ARRAY_APPEND(p0.external_ids, ds.external_id)::varchar(255)[] AS external_ids, p0.v_sum + v.version + 1 AS v_sum
    FROM data_structure_versions v
    INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
    INNER JOIN data_structure_relations AS r ON r.parent_id = v.id
    INNER JOIN relation_types AS t ON t.id = r.relation_type_id AND t.name = 'default'
    INNER JOIN paths AS p0 ON p0.id = r.child_id
  )
  """

  def by_data_structure_id(query, data_structure_id) do
    query
    |> recursive_ctes(true)
    |> with_cte("paths", as: fragment(@paths_by_structure_id, type(^data_structure_id, :integer)))
    |> join(:inner, [dsv], p in {"paths", Path}, on: p.vid == dsv.id)
    |> select_merge([dsv, p], %{path: p})
    |> distinct_by(:data_structure_id)
  end

  def by_version_id(query, id) do
    query
    |> recursive_ctes(true)
    |> with_cte("paths", as: fragment(@paths_by_version_id, type(^id, :integer)))
    |> join(:inner, [dsv], p in {"paths", Path}, on: p.vid == dsv.id)
    |> select_merge([dsv, p], %{path: p})
    |> distinct_by(:id)
  end

  def by_structure_id_and_version(query, data_structure_id, version) do
    query
    |> recursive_ctes(true)
    |> with_cte("paths",
      as:
        fragment(
          @paths_by_structure_id_and_version,
          type(^data_structure_id, :integer),
          type(^version, :integer)
        )
    )
    |> join(:inner, [dsv], p in {"paths", Path}, on: p.vid == dsv.id)
    |> select_merge([dsv, p], %{path: p})
    |> distinct_by(:id)
  end

  def with_path(query, opts \\ []) do
    query
    |> recursive_ctes(true)
    |> with_cte("paths", as: fragment(@all_paths))
    |> join(:left, [dsv], p in {"paths", Path}, on: p.id == dsv.id)
    |> select_merge([dsv, p], %{path: p})
    |> distinct_by(opts[:distinct])
  end

  defp distinct_by(query, nil), do: query

  defp distinct_by(query, :id) do
    query
    |> distinct(:id)
    |> order_by([dsv, path], asc: dsv.id, desc: path.v_sum)
  end

  defp distinct_by(query, :data_structure_id) do
    query
    |> distinct(:data_structure_id)
    |> order_by([dsv, path], asc: dsv.data_structure_id, desc: dsv.version, desc: path.v_sum)
  end
end
