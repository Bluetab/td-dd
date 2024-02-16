defmodule TdDd.Repo.Migrations.CreateDataStructureForeignKeyIndices do
  use Ecto.Migration

  def change do
    create index("data_structures_hierarchy", [:ancestor_ds_id])
    create index("implementations_structures", [:data_structure_id])
    create index("nodes", [:structure_id])
    create index("profile_executions", [:data_structure_id])
    create index("structure_metadata", [:data_structure_id])
  end
end
