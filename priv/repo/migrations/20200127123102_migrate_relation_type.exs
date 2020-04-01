defmodule TdDd.Repo.Migrations.MigrateRelationType do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now()

    execute("""
    insert into relation_types(name, description, inserted_at, updated_at)
    values('default', 'Parent/Child', now(), now())
    """)

    execute("""
    update data_structure_relations
    set relation_type_id = (select id from relation_types where name = 'default')
    """)

    alter table("data_structure_relations") do
      modify(:relation_type_id, :integer, null: false)
    end
  end

  def down do
    execute("update data_structure_relations set relation_type_id = null")
    execute("delete from relation_types where name = 'default'")
  end
end
