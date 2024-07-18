defmodule TdDd.Repo.Migrations.AddEdgeIndexLinage do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX edges_end_id_hash_index ON edges USING hash(end_id);")
    execute("CREATE INDEX edges_type_hash_index ON edges USING hash(type);")
    execute("CREATE INDEX edges_end_id_type_btree_index ON edges USING btree(end_id, type);")

    execute("CREATE INDEX edges_start_id_hash_index ON edges USING hash(start_id);")
    execute("CREATE INDEX edges_start_id_btree_index ON edges USING btree(start_id);")
  end

  def down do
    execute("DROP INDEX IF EXISTS edges_start_id_btree_index;")
    execute("DROP INDEX IF EXISTS edges_start_id_hash_index;")
    execute("DROP INDEX IF EXISTS edges_end_id_type_btree_index;")
    execute("DROP INDEX IF EXISTS edges_type_hash_index;")
    execute("DROP INDEX IF EXISTS edges_end_id_hash_index;")
  end
end
