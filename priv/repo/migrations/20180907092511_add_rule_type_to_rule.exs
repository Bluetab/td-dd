defmodule TdDq.Repo.Migrations.AddRuleTypeToRule do
  use Ecto.Migration

  def up do
    alter table("rules"), do: add(:rule_type_id, references(:rule_types), null: true)

    execute(
      "update rules set rule_type_id = (select id from rule_types as rt where rt.name = type)"
    )

    alter table("rules"), do: modify(:rule_type_id, :bigint, null: false)
    rename table("rules"), :type, to: :type_backup
    rename table("rule_implementations"), :rule_type_id, to: :rule_type_id_backup
  end

  def down do
    rename table("rule_implementations"), :rule_type_id_backup, to: :rule_type_id
    rename table("rules"), :type_backup, to: :type
    alter table("rules"), do: remove(:rule_type_id)
  end
end
