defmodule TdDd.Lineage.NodeQuery do
  @moduledoc """
  Query module for node domain ids
  """

  import Ecto.Query

  alias TdDd.Lineage.Units.Node
  alias TdDd.Repo

  @query_all """
  SELECT * FROM (
    WITH RECURSIVE node_agg_domain_ids AS
    (SELECT e.start_id AS parent_id,
            n.id AS child_id,
            unnest(ds.domain_ids) AS domain_ids
    FROM nodes n
    LEFT JOIN edges e ON e.end_id = n.id
    AND e.type = 'CONTAINS'
    LEFT JOIN data_structures ds ON n.structure_id = ds.id
    WHERE n.structure_id IS NOT NULL
    UNION
      (SELECT e.start_id AS parent_id,
              agg.parent_id AS child_id,
              unnest(agg.domain_ids) AS domain_ids
        FROM
          (SELECT DISTINCT parent_id,
                          array_agg(domain_ids) OVER (PARTITION BY parent_id) AS domain_ids
          FROM node_agg_domain_ids
          WHERE parent_id IS NOT NULL ) agg
        LEFT JOIN nodes n ON n.id = agg.parent_id
        LEFT JOIN edges e ON e.end_id = n.id
        AND e.type = 'CONTAINS'
        LEFT JOIN data_structures ds ON n.structure_id = ds.id))
    SELECT child_id,
        Array_agg(domain_ids) as domain_ids
    FROM node_agg_domain_ids
    GROUP BY child_id
  ) AS SUBQ
  """

  def nodes_domain_ids do
    "nodes_domain_ids"
    |> with_cte("nodes_domain_ids", as: fragment(@query_all))
    |> select([:child_id, :domain_ids])
    |> Repo.all()
  end

  def list_structure_domain_ids do
    Node
    |> where([n], not is_nil(n.structure_id))
    |> join(:left, [n], ds in assoc(n, :structure))
    |> select([_n, ds], ds.domain_ids)
    |> distinct(true)
    |> Repo.all()
    |> List.flatten()
  end
end
