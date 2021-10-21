defmodule TdDd.Repo.Migrations.AddExplainColumnToRuleResults do
  use Ecto.Migration

  def up do
    alter(table("rule_results"), do: add(:details, :map, default: %{}))
  end

  def down do
    alter(table("rule_results"), do: remove(:details))
  end
end
