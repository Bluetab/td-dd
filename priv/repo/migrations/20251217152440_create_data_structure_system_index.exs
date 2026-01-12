defmodule TdDd.Repo.Migrations.CreateDataStructureSystemIndex do
  use Ecto.Migration

  def change do
    create index(:data_structures, [:system_id, :id])
  end
end
