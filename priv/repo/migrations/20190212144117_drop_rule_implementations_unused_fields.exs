defmodule TdDq.Repo.Migrations.DropRuleImplementationsUnusedFields do
  use Ecto.Migration

  def change do
    drop constraint(:rule_implementations, "quality_rules_quality_rule_type_id_fkey")

    alter table(:rule_implementations) do
      remove :type_backup
      remove :rule_type_id_backup
    end
  end
end
