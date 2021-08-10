defmodule TdDd.Repo.Migrations.AlterStructureMetadataTimestampPrecision do
  use Ecto.Migration

  def change do
    alter table("structure_metadata") do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:deleted_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
