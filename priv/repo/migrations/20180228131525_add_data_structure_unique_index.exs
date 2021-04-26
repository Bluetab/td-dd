defmodule TdDd.Repo.Migrations.AddDataStructureUniqueIndex do
  use Ecto.Migration

  def change do
    create unique_index(:data_structures, [:system, :group, :name])
  end
end
