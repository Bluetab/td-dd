defmodule TdDd.Repo.Migrations.AlterDataStructureRelationTimestampPrecision do
  use Ecto.Migration

  def change do
    alter table(:data_structure_relations) do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
