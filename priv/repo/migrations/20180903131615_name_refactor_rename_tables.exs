defmodule TdDq.Repo.Migrations.NameRefactorRenameTables do
  use Ecto.Migration

  def up do
    execute("alter table quality_controls rename constraint quality_controls_pkey to rules_pkey")

    execute(
      "alter table quality_rules rename constraint quality_rules_pkey to rule_implementations_pkey"
    )

    execute(
      "alter table quality_rule_types rename constraint quality_rule_types_pkey to rule_types_pkey"
    )

    execute(
      "alter table quality_rules rename constraint quality_rules_quality_control_id_fkey  to rule_implementations_rule_id_fkey"
    )

    rename table("quality_controls"), to: table("rules")
    rename table("quality_controls_results"), to: table("rule_results")
    rename table("quality_rules"), to: table("rule_implementations")
    rename table("quality_rule_types"), to: table("rule_types")
  end

  def down do
    execute("alter table rules rename constraint rules_pkey  to quality_controls_pkey")

    execute(
      "alter table rule_implementations rename constraint rule_implementations_pkey to quality_rules_pkey"
    )

    execute("alter table rule_types rename constraint rule_types_pkey to quality_rule_types_pkey")

    execute(
      "alter table rule_implementations rename constraint rule_implementations_rule_id_fkey  to quality_rules_quality_control_id_fkey"
    )

    rename table("rules"), to: table("quality_controls")
    rename table("rule_results"), to: table("quality_controls_results")
    rename table("rule_implementations"), to: table("quality_rules")
    rename table("rule_types"), to: table("quality_rule_types")
  end
end
