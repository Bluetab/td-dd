defmodule TdDq.Repo.Migrations.DropRuleResultsBackup do
  use Ecto.Migration

  def change do
    execute("delete from rule_results_backup")
    drop table("rule_results_backup")
  end
end
