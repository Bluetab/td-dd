defmodule TdDd.Repo.Migrations.SoftDeleteOrphanFields do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def up do
    ts = DateTime.utc_now()

    orphan_ids =
      Repo.all(
        from(dsv in "data_structure_versions",
          where: is_nil(dsv.deleted_at),
          where: dsv.class == "field",
          left_join: p in "data_structure_relations",
          on: p.child_id == dsv.id,
          where: is_nil(p),
          select: dsv.id
        )
      )

    Repo.update_all(
      from(dsv in "data_structure_versions",
        where: dsv.id in ^orphan_ids,
        update: [set: [deleted_at: ^ts]]
      ),
      []
    )
  end

  def down do
  end
end
