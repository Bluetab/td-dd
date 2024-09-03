defmodule TdDd.Repo.Migrations.AddUnitsIndexLinage do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX units_nodes_node_id_hash_index ON units_nodes USING hash (node_id);")

    execute("CREATE INDEX units_nodes_node_id_btree_index ON units_nodes USING btree (node_id);")
  end

  def down do
    execute("DROP INDEX IF EXISTS units_nodes_node_id_btree_index;")
    execute("DROP INDEX IF EXISTS units_nodes_node_id_hash_index;")
  end
end
