defmodule TdDd.Repo.Migrations.SoftDeleteObsoleteVersions do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def up do
    ts = DateTime.utc_now()

    Repo.update_all(
      from(dsv in "data_structure_versions",
        where: is_nil(dsv.deleted_at),
        join: ds in "data_structures",
        on: ds.id == dsv.data_structure_id,
        join: newer in "data_structure_versions",
        on: newer.data_structure_id == ds.id,
        where: is_nil(newer.deleted_at),
        where: newer.version > dsv.version,
        update: [set: [deleted_at: ^ts]]
      ),
      []
    )
  end

  def down do
  end
end
