defmodule TdDd.Repo.Migrations.AddDomainIdsToReferenceDatasets do
  use Ecto.Migration

  def change do
    alter table("reference_datasets") do
      add :domain_ids, {:array, :integer}, default: [], null: false
    end
  end
end
