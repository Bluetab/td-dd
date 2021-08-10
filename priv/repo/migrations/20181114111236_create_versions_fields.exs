defmodule TdDd.Repo.Migrations.CreateVersionsFields do
  use Ecto.Migration

  def up do
    create table("versions_fields", primary_key: false) do
      add(:data_structure_version_id, references("data_structure_versions"))
      add(:data_field_id, references("data_fields"))
    end

    execute("""
    insert into versions_fields(data_structure_version_id, data_field_id)
    select v.id, f.id
    from data_structures s
    join data_structure_versions v on v.data_structure_id = s.id
    join data_fields f on f.data_structure_id = s.id
    """)

    create index("versions_fields", [:data_structure_version_id])
    create index("versions_fields", [:data_field_id])
  end

  def down do
    drop table("versions_fields")
  end
end
