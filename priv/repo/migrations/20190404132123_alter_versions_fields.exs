defmodule TdDd.Repo.Migrations.AlterVersionsFields do
  use Ecto.Migration

  def up do
    execute(
      "ALTER TABLE versions_fields DROP CONSTRAINT versions_fields_data_structure_version_id_fkey"
    )

    execute("ALTER TABLE versions_fields DROP CONSTRAINT versions_fields_data_field_id_fkey")

    alter table("versions_fields") do
      modify(:data_structure_version_id, references(:data_structure_versions, on_delete: :delete_all))
      modify(:data_field_id, references(:data_fields, on_delete: :delete_all))
    end
  end

  def down do
    execute(
      "ALTER TABLE versions_fields DROP CONSTRAINT versions_fields_data_structure_version_id_fkey"
    )

    execute("ALTER TABLE versions_fields DROP CONSTRAINT versions_fields_data_field_id_fkey")

    alter table("versions_fields") do
      modify(:data_structure_version_id, references(:data_structure_versions, on_delete: :nothing))
      modify(:data_field_id, references(:data_fields, on_delete: :nothing))
    end
  end
end
