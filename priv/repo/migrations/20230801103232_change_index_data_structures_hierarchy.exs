defmodule TdDd.Repo.Migrations.ChangeIndexDataStructuresHierarchy do
  use Ecto.Migration

  def up do
    drop_if_exists(
      index("data_structures_hierarchy", [
        "dsv_id_ancestor_dsv_id_ancestor_level"
      ])
    )

    drop_if_exists(index("units_nodes", ["unit_id_node_id"]))

    drop_if_exists(index("data_structures_hierarchy", ["ds_id"]))

    create(index("data_structures_hierarchy", [:ds_id], where: "ds_id IS NOT NULL"))

    drop_if_exists(index("data_structures_hierarchy", ["ancestor_ds_id"]))

    create(
      index(
        "data_structures_hierarchy",
        [:ancestor_ds_id],
        where: "ancestor_ds_id IS NOT NULL"
      )
    )

    execute("
    REINDEX INDEX data_structures_hierarchy_pkey;
    ")

    execute("
    REINDEX INDEX data_structures_hierarchy_ancestor_dsv_id_index;
    ")

    execute("
    REINDEX INDEX data_structures_hierarchy_dsv_id_index;
    ")
  end

  def down do
    drop_if_exists(index("data_structures_hierarchy", ["ancestor_ds_id"]))

    drop_if_exists(index("data_structures_hierarchy", ["ds_id"]))

    create(index("data_structures_hierarchy", [:dsv_id, :ancestor_dsv_id, :ancestor_level]))
    create(index("units_nodes", [:unit_id, :node_id]))
    create(index("data_structures_hierarchy", [:ds_id]))
    create(index("data_structures_hierarchy", [:ancestor_ds_id]))
  end
end
