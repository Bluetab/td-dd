defmodule TdDd.Repo.Migrations.DropColumnDataFieldsDataStructureId do
  use Ecto.Migration

  def up do
    drop unique_index("data_fields", [:data_structure_id, :name])

    alter table("data_fields") do
      remove :data_structure_id
    end
  end

  def down do
    alter table("data_fields") do
      add :data_structure_id, :integer
    end

    execute("""
    update data_fields f
    set data_structure_id = v.data_structure_id
    from versions_fields vf
    join data_structure_versions v on v.id = vf.data_structure_version_id
    where vf.data_field_id = f.id
    """)

    alter table("data_fields") do
      modify :data_structure_id, references("data_structures", on_delete: :nothing)
    end

    create index("data_fields", [:data_structure_id])

    create unique_index("data_fields", [:data_structure_id, :name])
  end
end
