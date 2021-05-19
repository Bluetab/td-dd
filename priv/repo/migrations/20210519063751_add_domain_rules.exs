defmodule TdDd.Repo.Migrations.AddDomainRules do
  use Ecto.Migration

  def up do
    alter(table(:rules)) do
      add(:domain_id, :bigint)
    end
  end

  def down do
    alter(table(:rules)) do
      remove(:domain_id, :bigint)
    end
  end
end
