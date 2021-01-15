EXPLAIN ANALYZE WITH RECURSIVE "paths" AS (SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY[v.name] AS names, ARRAY[v.data_structure_id] AS structure_ids, ARRAY[ds.external_id] AS external_ids, v.version + 1 AS v_sum
FROM data_structure_versions v
INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
WHERE ds.id = 4856
UNION ALL
SELECT v.id AS id, p0.vid AS vid, v.name AS name, ARRAY_APPEND(p0.names, v.name)::varchar(255)[] AS names, ARRAY_APPEND(p0.structure_ids, v.data_structure_id)::bigint[] AS structure_ids, ARRAY_APPEND(p0.external_ids, ds.external_id)::varchar(255)[] AS external_ids, p0.v_sum + v.version + 1 AS v_sum
FROM data_structure_versions v
INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
INNER JOIN data_structure_relations AS r ON r.parent_id = v.id
INNER JOIN relation_types AS t ON t.id = r.relation_type_id AND t.name = 'default'
INNER JOIN paths AS p0 ON p0.id = r.child_id
) SELECT DISTINCT ON (d0."data_structure_id") d0.*, p1.*
FROM "data_structure_versions" AS d0
INNER JOIN "paths" AS p1 ON p1."vid" = d0."id"
ORDER BY d0."data_structure_id", d0."data_structure_id", d0."version" DESC, p1."v_sum" DESC;

EXPLAIN ANALYZE WITH RECURSIVE "paths" AS (SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY[v.name] AS names, ARRAY[v.data_structure_id] AS structure_ids, ARRAY[ds.external_id] AS external_ids, v.version + 1 AS v_sum
FROM data_structure_versions v
INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
LEFT OUTER JOIN data_structure_relations AS r ON r.child_id = v.id
LEFT OUTER JOIN relation_types t ON t.id = r.relation_type_id AND t.name = 'default'
WHERE r.id IS NULL
UNION ALL (
  SELECT v.id AS id, v.id AS vid, v.name AS name, ARRAY_PREPEND(v.name, p0.names)::varchar(255)[] AS names, ARRAY_PREPEND(v.data_structure_id, p0.structure_ids)::bigint[] AS structure_ids, ARRAY_PREPEND(ds.external_id, p0.external_ids)::text[] AS external_ids, p0.v_sum + v.version + 1 AS v_sum
  FROM data_structure_versions v
  INNER JOIN data_structures AS ds ON ds.id = v.data_structure_id
  INNER JOIN data_structure_relations as r ON r.child_id = v.id
  INNER JOIN relation_types t ON t.id = r.relation_type_id AND t.name = 'default'
  INNER JOIN paths p0 on p0.id = r.parent_id
)
)
SELECT DISTINCT ON (d0."data_structure_id") d0.*, p1.*
FROM "data_structure_versions" AS d0
LEFT OUTER JOIN "paths" AS p1 ON p1."id" = d0."id"
ORDER BY d0."data_structure_id", d0."data_structure_id", d0."version" DESC, p1."v_sum" DESC;
