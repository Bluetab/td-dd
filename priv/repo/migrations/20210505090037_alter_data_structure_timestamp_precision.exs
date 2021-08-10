defmodule TdDd.Repo.Migrations.AlterDataStructureTimestampPrecision do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
