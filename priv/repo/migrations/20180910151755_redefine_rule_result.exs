defmodule TdDq.Repo.Migrations.RedefineRuleResult do
  use Ecto.Migration

  def up do
    rename table(:rule_results), to: table(:rule_results_backup)

    create table(:rule_results) do
      add :date, :utc_datetime
      add :result, :integer
      add :rule_implementation_id, references(:rule_implementations)
      timestamps()
    end
  end

  def down do
    drop table(:rule_results)
    rename table(:rule_results_backup), to: table(:rule_results)
  end

end
