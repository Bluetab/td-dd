defmodule TdDd.Repo.Migrations.AlterDataStructureVersions do
  use Ecto.Migration

  def up do
    execute(
      "ALTER TABLE data_structure_versions DROP CONSTRAINT data_structure_versions_data_structure_id_fkey"
    )

    alter table("data_structure_versions") do
      modify(:data_structure_id, references("data_structures", on_delete: :delete_all))
    end
  end

  def down do
    execute(
      "ALTER TABLE data_structure_versions DROP CONSTRAINT data_structure_versions_data_structure_id_fkey"
    )

    alter table("data_structure_versions") do
      modify(:data_structure_id, references("data_structures", on_delete: :nothing))
    end
  end
end
