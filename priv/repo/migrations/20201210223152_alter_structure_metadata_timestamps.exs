defmodule TdDd.Repo.Migrations.AlterStructureMetadataTimestamps do
  use Ecto.Migration

  def change do
    alter table("structure_metadata") do
      modify(:inserted_at, :utc_datetime, from: :naive_datetime)
      modify(:updated_at, :utc_datetime, from: :naive_datetime)
    end
  end
end
