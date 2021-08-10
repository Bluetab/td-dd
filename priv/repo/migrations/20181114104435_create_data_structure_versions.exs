defmodule TdDd.Repo.Migrations.CreateDataStructureVersions do
  use Ecto.Migration

  def up do
    create table("data_structure_versions") do
      add(:version, :integer, null: false, default: 0)
      add(:data_structure_id, references("data_structures", on_delete: :nothing))

      timestamps(type: :utc_datetime)
    end

    execute("""
    insert into data_structure_versions(version, data_structure_id, inserted_at, updated_at)
    select 0, id, inserted_at, updated_at from data_structures
    """)
  end

  def down do
    drop table("data_structure_versions")
  end
end
