defmodule TdDd.Repo.Migrations.AddNodeIndexLinage do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX nodes_external_id_hash_index ON public.nodes USING hash (external_id);")

    execute(
      "CREATE UNIQUE INDEX nodes_external_id_btree_index ON public.nodes USING btree (external_id);"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS nodes_external_id_btree_index;")
    execute("DROP INDEX IF EXISTS nodes_external_id_hash_index;")
  end
end
