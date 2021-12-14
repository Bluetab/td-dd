defmodule TdDd.Repo.Migrations.CreateDataStructuresHierarchy do
  use Ecto.Migration

  def change do
    create table("data_structures_hierarchy", primary_key: false) do
      add :dsv_id, references("data_structure_versions", on_delete: :delete_all), primary_key: true
      add :ds_id, references("data_structures", on_delete: :delete_all)
      add :ancestor_dsv_id, references("data_structure_versions", on_delete: :delete_all), primary_key: true
      add :ancestor_ds_id, references("data_structures", on_delete: :delete_all)
      add :ancestor_level, :integer, null: false
    end

    create index("data_structures_hierarchy", [:dsv_id, :ancestor_dsv_id, :ancestor_level], unique: true)
    create index("data_structures_hierarchy", [:dsv_id])
    create index("data_structures_hierarchy", [:ancestor_dsv_id])

    execute(
      """
      INSERT into data_structures_hierarchy (dsv_id, ds_id, ancestor_dsv_id, ancestor_ds_id, ancestor_level)
      WITH recursive data_structures_hierarchy as (
        SELECT
          id as dsv_id,
          data_structure_id as ds_id,
          id as ancestor_dsv_id,
          data_structure_id as ancestor_ds_id,
          0 as ancestor_level
        FROM data_structure_versions
        UNION (
          SELECT dsv_id, ds_id, dsv.id, dsv.data_structure_id, ancestor_level + 1
          FROM data_structures_hierarchy dsh
          JOIN data_structure_relations dsr on dsr.child_id = dsh.ancestor_dsv_id
          JOIN relation_types AS rt ON rt.id = dsr.relation_type_id AND rt.name = 'default'
          JOIN data_structure_versions dsv on dsv.id = dsr.parent_id
        )
      )
      SELECT dsv_id, ds_id, ancestor_dsv_id, ancestor_ds_id, ancestor_level
      FROM data_structures_hierarchy
      """,
      ""
    )
  end
end
