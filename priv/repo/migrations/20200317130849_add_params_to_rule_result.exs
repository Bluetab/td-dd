defmodule TdDq.Repo.Migrations.AddParamsToRuleResult do
  use Ecto.Migration

  def up do
    alter(table(:rule_results), do: add(:params, :map, default: %{}))
  end

  def down do
    alter(table(:rule_results), do: remove(:params))
  end
end
