defmodule TdDd.Repo.Migrations.ChangeImplementationKeyForIdOnRuleResult do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      add(:implementation_id, references("rule_implementations", on_delete: :nilify_all))
    end

    execute(
      """
      UPDATE rule_results SET (implementation_id) =
        (SELECT id FROM rule_implementations
         WHERE rule_implementations.implementation_key = rule_results.implementation_key)
      """,
      """
      UPDATE rule_results SET (implementation_key) =
        (SELECT implementation_key FROM rule_implementations
         WHERE rule_implementations.id = rule_results.implementation_id)
      """
    )


    alter table("rule_results") do
      remove(:implementation_key)
    end
  end
end
