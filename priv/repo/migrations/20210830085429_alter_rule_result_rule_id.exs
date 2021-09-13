defmodule TdDd.Repo.Migrations.AlterRuleResultRuleId do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      add(:rule_id, references("rules", on_delete: :nilify_all))
    end

    execute(
      """
      UPDATE rule_results SET (rule_id) =
        (SELECT rule_id FROM rule_implementations
         WHERE rule_implementations.implementation_key = rule_results.implementation_key)
      """,
      ""
    )
  end
end
