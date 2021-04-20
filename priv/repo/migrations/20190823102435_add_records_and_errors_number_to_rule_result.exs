defmodule TdDq.Repo.Migrations.AddRecordsAndErrorsNumberToRuleResult do
  use Ecto.Migration

  def change do
    alter(table(:rule_results), do: add(:records, :integer))
    alter(table(:rule_results), do: add(:errors, :integer))
  end
end
