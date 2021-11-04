defmodule TdDd.Repo.Migrations.MoveGoalAndMinimumFromRuleToImplementation do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      add(:goal, :integer)
      add(:minimum, :integer)
      add(:result_type, :string, default: "percentage")
    end

    execute(
      """
      UPDATE rule_implementations SET (goal, minimum, result_type) = (
        SELECT goal, minimum, result_type FROM rules
        WHERE rule_implementations.rule_id = rules.id
      )
      """,
      """
      UPDATE rules SET (goal, minimum, result_type) = (
        SELECT DISTINCT ON (rule_id) goal, minimum, result_type
        FROM rule_implementations
        WHERE rule_implementations.rule_id = rules.id
      )
      """
    )

    alter table("rules") do
      remove(:goal, :integer)
      remove(:minimum, :integer)
      remove(:result_type, :string, default: "percentage")
    end
  end
end
