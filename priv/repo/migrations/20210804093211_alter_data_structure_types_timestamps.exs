defmodule TdDd.Repo.Migrations.AlterDataStructureTypesTimestamps do
  use Ecto.Migration

  def change do
    alter table("data_structure_types") do
      modify(:inserted_at, :utc_datetime_usec, from: :naive_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :naive_datetime)
    end
  end
end
