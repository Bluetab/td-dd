defmodule TdDq.Repo.Migrations.RenameTables do
  use Ecto.Migration

  def up do
    rename table("quality_controls"), to: table("rules")
    rename table("quality_controls_results"), to: table("rule_results")
    rename table("quality_rules"), to: table("rule_implementations")
    rename table("quality_rule_types"), to: table("rule_types")
  end

  def down do
    rename table("rules"), to: table("quality_controls")
    rename table("rule_results"), to: table("quality_controls_results")
    rename table("rule_implementations"), to: table("quality_rules")
    rename table("rule_types"), to: table("quality_rule_types")
  end
end
