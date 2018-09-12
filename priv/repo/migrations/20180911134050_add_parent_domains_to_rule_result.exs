defmodule TdDq.Repo.Migrations.AddParentDomainsToRuleResult do
  use Ecto.Migration
  alias Ecto.Adapters.SQL
  alias TdDq.Repo

  def up do
    alter table(:rule_results), do: add :parent_domains, :text, null: true
    flush()
    SQL.query!(Repo, "update rule_results set parent_domains = ''")
    alter table(:rule_results), do: modify :parent_domains, :text, null: false
  end

  def down do
    alter table(:rule_results), do: remove :parent_domains
  end
end
