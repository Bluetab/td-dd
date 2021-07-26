defmodule TdDd.Repo.Migrations.UpdateDataStructuresExternalId do
  use Ecto.Migration

  def change do
    execute(
      "update data_structures ds set external_id = concat_ws(':', s.external_id, ds.group, ds.name) from systems s where s.id = ds.system_id and ds.external_id is null;"
    )
  end
end
