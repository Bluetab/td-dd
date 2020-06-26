defmodule TdDq.Repo.Migrations.RemoveRuleResultsParentDomains do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      remove(:parent_domains, :text, null: false, default: "")
    end
  end
end
