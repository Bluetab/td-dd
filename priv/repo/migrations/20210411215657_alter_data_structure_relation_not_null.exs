defmodule TdDd.Repo.Migrations.AlterDataStructureRelationNotNull do
  use Ecto.Migration

  def up do
    execute "DELETE FROM data_structure_relations WHERE parent_id IS NULL or child_id IS NULL"

    execute "ALTER TABLE data_structure_relations DROP CONSTRAINT data_structure_relations_child_id_fkey"

    execute "ALTER TABLE data_structure_relations DROP CONSTRAINT data_structure_relations_parent_id_fkey"

    alter table("data_structure_relations") do
      modify :child_id, references("data_structure_versions", on_delete: :delete_all), null: false

      modify :parent_id, references("data_structure_versions", on_delete: :delete_all),
        null: false
    end
  end

  def down do
    execute "ALTER TABLE data_structure_relations DROP CONSTRAINT data_structure_relations_child_id_fkey"

    execute "ALTER TABLE data_structure_relations DROP CONSTRAINT data_structure_relations_parent_id_fkey"

    alter table("data_structure_relations") do
      modify :child_id, references("data_structure_versions", on_delete: :delete_all)
      modify :parent_id, references("data_structure_versions", on_delete: :delete_all)
    end
  end
end
