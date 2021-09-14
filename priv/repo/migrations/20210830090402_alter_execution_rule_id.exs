defmodule TdDd.Repo.Migrations.AlterExecutionRuleId do
  use Ecto.Migration

  def change do
    alter table("executions") do
      add(:rule_id, references("rules", on_delete: :nilify_all))
    end

    execute(
      """
      UPDATE executions SET (rule_id) =
        (SELECT rule_id FROM rule_implementations
         WHERE rule_implementations.id = executions.implementation_id)
      """,
      ""
    )
  end
end
