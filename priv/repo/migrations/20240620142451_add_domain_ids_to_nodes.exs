defmodule TdDd.Repo.Migrations.AddDomainIdsToNodes do
  use Ecto.Migration

  def change do
    alter table(:nodes) do
      add :domain_ids, {:array, :integer}, default: []
    end
  end
end
