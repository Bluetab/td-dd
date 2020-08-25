defmodule TdDd.Repo.Migrations.AddDomainIdToUnit do
  use Ecto.Migration

  def up do
    alter table(:units) do
      add(:domain_id, :integer, default: nil, null: true)
    end
  end

  def down do
    alter table(:units) do
      remove(:domain_id, :integer, default: nil, null: true)
    end
  end
end
