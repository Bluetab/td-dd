defmodule TdDd.Repo.Migrations.DeleteDuplicateFields do
  use Ecto.Migration

  def up do
    execute("""
    delete from data_fields where id not in (select data_field_id from versions_fields)
    """)
  end

  def down do
    
  end
end
