defmodule TdDd.Repo.Migrations.AddDomainRules do
  use Ecto.Migration

  def change do
    alter table("rules") do
      add(:domain_id, :bigint)
    end
  end
end
