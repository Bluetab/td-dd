defmodule TdDd.Repo.Migrations.MigrateDataStructureMutableColumns do
  use Ecto.Migration

  def up do
    execute("""
    update data_structure_versions dsv
    set class = ds.class, deleted_at = ds.deleted_at, description = ds.description, "group" = ds.group, metadata = ds.metadata, name = ds.name, type = ds.type
    from data_structures ds
    where ds.id = dsv.data_structure_id;
    """)
  end

  def down do
    execute("""
    update data_structures ds
    set class = dsv.class, deleted_at = dsv.deleted_at, description = dsv.description, "group" = dsv.group, metadata = dsv.metadata, name = dsv.name, type = dsv.type
    from (
      select data_structure_id, class, deleted_at, description, "group", metadata, name, type from data_structure_versions where id not in (
        select distinct dsv1.id from data_structure_versions dsv1 join data_structure_versions dsv2 on dsv1.data_structure_id = dsv2.data_structure_id and dsv1.version < dsv2.version
      )) as dsv
    where dsv.data_structure_id = ds.id;
    """)
  end
end
