defmodule TdDd.Repo.Migrations.AlterDataStructureVersionTimestampPrecision do
  use Ecto.Migration

  def change do
    alter table(:data_structure_versions) do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:deleted_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
