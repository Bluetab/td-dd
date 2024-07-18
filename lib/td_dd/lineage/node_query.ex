defmodule TdDd.Lineage.NodeQuery do
  @moduledoc """
  Query module for node domain ids
  """

  import Ecto.Query

  require Logger

  alias TdDd.Lineage.Units.Node
  alias TdDd.Repo

  @update_nodes_domains_ids """
  UPDATE nodes AS n
  SET domain_ids =query.domain_ids
  FROM
  (SELECT child_id, ARRAY_AGG(DISTINCT domain_ids) AS domain_ids
  FROM(select child_id, UNNEST (domain_ids) AS domain_ids
    FROM(
    WITH RECURSIVE node_agg_domain_ids AS (
      SELECT e.start_id AS parent_id, n.id AS child_id, ds.domain_ids
      FROM nodes n
      LEFT JOIN edges e ON e.end_id = n.id AND e.type = 'CONTAINS'
      INNER JOIN data_structures ds ON n.structure_id = ds.id union
        (SELECT e.start_id AS parent_id, agg.parent_id AS child_id, agg.domain_ids
        FROM (SELECT DISTINCT parent_id, domain_ids
          FROM node_agg_domain_ids
          WHERE parent_id IS NOT NULL) agg
        LEFT JOIN nodes n ON n.id = agg.parent_id
        LEFT JOIN edges e ON e.end_id = n.id AND e.type = 'CONTAINS'
        LEFT JOIN data_structures ds ON n.structure_id = ds.id)
      )
    SELECT child_id, domain_ids
    FROM node_agg_domain_ids
    GROUP BY child_id, domain_ids
    ) AS SUBQ
    UNION
    SELECT un.node_id AS child_id, domain_id AS domain_ids
    FROM units AS n
    LEFT JOIN units_nodes AS un ON n.id = un.unit_id
  ) AS X
  GROUP BY child_id) AS query
  WHERE n.id = query.child_id;
  """

  def list_structure_domain_ids do
    Node
    |> where([n], not is_nil(n.structure_id))
    |> join(:left, [n], ds in assoc(n, :structure))
    |> select([_n, ds], ds.domain_ids)
    |> distinct(true)
    |> Repo.all()
    |> List.flatten()
  end

  def update_nodes_domains do
    Logger.info("Starting update_nodes_domains")

    @update_nodes_domains_ids
    |> Repo.query()
    |> execution_result(@update_nodes_domains_ids)
  end

  defp execution_result({:error, error} = result, instruction) do
    Logger.error("Error while executing the instruction '#{instruction}': #{inspect(error)}")
    result
  end

  defp execution_result({:ok, %{num_rows: num_rows}} = result, _) do
    Logger.info("Finished update_nodes_domains with #{num_rows} num_rows updated")
    result
  end
end
