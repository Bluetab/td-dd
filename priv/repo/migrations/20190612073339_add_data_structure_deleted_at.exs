defmodule TdDd.Repo.Migrations.AddDataStructureDeletedAt do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      add :deleted_at, :utc_datetime, null: true
    end
  end
end
