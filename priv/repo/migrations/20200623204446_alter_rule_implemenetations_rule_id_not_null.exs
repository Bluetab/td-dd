defmodule TdDq.Repo.Migrations.AlterRuleImplemenetationsRuleIdNotNull do
  use Ecto.Migration

  def up do
    drop(constraint("rule_implementations", :rule_implementations_rule_id_fkey))

    alter table("rule_implementations") do
      modify(:rule_id, references("rules", on_delete: :nothing), null: false)
    end
  end

  def down do
    drop(constraint("rule_implementations", :rule_implementations_rule_id_fkey))

    alter table("rule_implementations") do
      modify(:rule_id, references("rules", on_delete: :nothing), null: true)
    end
  end
end
