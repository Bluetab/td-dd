defmodule TdDq.Repo.Migrations.RemoveRuleImplementationType do
  use Ecto.Migration

  def up do
    rename table("rule_implementations"), :type, to: :type_backup
  end

  def down do
    rename table("rule_implementations"), :type_backup, to: :type
  end
end
