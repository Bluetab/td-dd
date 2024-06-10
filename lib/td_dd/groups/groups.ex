defmodule TdDd.Groups do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.Repo

  def list_by_system(system_external_id) do
    Repo.all(
      from(dsv in DataStructureVersion,
        where: is_nil(dsv.deleted_at),
        join: ds in assoc(dsv, :data_structure),
        join: sys in assoc(ds, :system),
        where: sys.external_id == ^system_external_id,
        select: dsv.group,
        distinct: true
      )
    )
  end

  def delete(system_external_id, group, ts \\ DateTime.utc_now()) do
    {_count, data_structure_ids} =
      Repo.update_all(
        from(dsv in DataStructureVersion,
          where: dsv.group == ^group,
          where: is_nil(dsv.deleted_at),
          join: ds in assoc(dsv, :data_structure),
          join: sys in assoc(ds, :system),
          where: sys.external_id == ^system_external_id,
          update: [set: [deleted_at: ^ts]],
          select: dsv.data_structure_id
        ),
        []
      )

    data_structure_ids
    |> Enum.uniq()
    |> then(&Indexer.reindex(&1))
  end
end
