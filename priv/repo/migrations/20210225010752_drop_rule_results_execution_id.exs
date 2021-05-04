defmodule TdDq.Repo.Migrations.DropRuleResultsExecutionId do
  use Ecto.Migration

  def up do
    alter table("rule_results") do
      remove(:execution_id)
    end
  end

  def down do
    alter table("rule_results") do
      add(:execution_id, references("executions"), on_delete: :nilify_all)
    end

    execute(
      "UPDATE rule_results SET execution_id = e.id FROM executions AS e WHERE e.result_id = rule_results.id"
    )
  end
end
