defmodule TdDd.Repo.Migrations.AlterDataStructureTimestamps do
  use Ecto.Migration

  def up do
    alter table(:data_structures) do
      modify(:inserted_at, :utc_datetime)
      modify(:updated_at, :utc_datetime)
      remove(:last_change_at)
    end
  end

  def down do
    alter table(:data_structures) do
      add(:last_change_at, :utc_datetime)
    end

    execute("update data_structures set \"last_change_at\" = \"updated_at\";")
  end
end
