defmodule TdDd.Repo.Migrations.AlterDataStructureVersionTimestamps do
  use Ecto.Migration

  def change do
    alter table(:data_structure_versions) do
      modify(:inserted_at, :utc_datetime)
      modify(:updated_at, :utc_datetime)
    end
  end
end
