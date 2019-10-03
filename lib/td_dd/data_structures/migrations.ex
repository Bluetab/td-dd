defmodule TdDd.DataStructures.Migrations do
  @moduledoc """
  Migrations to be executed for Truedat 3.8
  """

  import Ecto.Query

  alias TdCache.Redix
  alias TdDd.Repo
  alias TdDd.DataStructures.DataStructureVersion

  def soft_delete_obsolete_versions(ts \\ DateTime.utc_now()) do
    Repo.update_all(
      from(dsv in DataStructureVersion,
        where: is_nil(dsv.deleted_at),
        join: ds in assoc(dsv, :data_structure),
        join: newer in assoc(ds, :versions),
        where: is_nil(newer.deleted_at),
        where: newer.version > dsv.version,
        update: [set: [deleted_at: ^ts]],
        select: dsv.id
      ),
      []
    )
  end

  # Migration to be executed once
  def soft_delete_orphan_fields(ts \\ DateTime.utc_now()) do
    orphan_ids =
      Repo.all(
        from(dsv in DataStructureVersion,
          where: is_nil(dsv.deleted_at),
          where: dsv.class == "field",
          left_join: p in assoc(dsv, :parents),
          where: is_nil(p),
          select: dsv.id
        )
      )

    Repo.update_all(
      from(dsv in DataStructureVersion,
        where: dsv.id in ^orphan_ids,
        update: [set: [deleted_at: ^ts]],
        select: dsv.id
      ),
      []
    )
  end

  # Ensure only one instance of dd is reindexing by creating a lock in Redis
  def can_migrate?(id) do
    Redix.command!(["SET", "TdDd.DataStructures.Migrations:" <> id, node(), "NX", "EX", 3600]) ==
      "OK"
  end
end
