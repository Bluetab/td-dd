defmodule TdDd.Repo.Migrations.AddIndexDataStructuresHierarchyDsId do
  use Ecto.Migration

  def up do
    # This index was created manually as a quick performance fix before this
    # migration was created
    drop_if_exists index(
                     "data_structures_hierarchy",
                     [:ds_id],
                     name: :data_structures_hierarchy_ds_id_idx
                   )

    create index("data_structures_hierarchy", [:ds_id])
  end

  def down do
    drop index("data_structures_hierarchy", [:ds_id])
  end
end
