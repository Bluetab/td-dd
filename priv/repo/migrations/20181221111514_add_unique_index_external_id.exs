defmodule TdDd.Repo.Migrations.AddUniqueIndexExternalId do
  use Ecto.Migration

  def change do
    drop index(:data_structures, [:system, :group, :name])
    create unique_index(:data_structures, [:system, :group, :name, :external_id])
  end
end
