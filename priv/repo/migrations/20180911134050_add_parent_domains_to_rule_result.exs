defmodule TdDq.Repo.Migrations.AddParentDomainsToRuleResult do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      add(:parent_domains, :text, null: false, default: "")
    end
  end
end
