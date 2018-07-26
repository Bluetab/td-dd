defmodule TdDd.Repo.Migrations.AddDomainIdToDataStructures do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      add :domain_id, :integer, null: true
    end
  end
end
