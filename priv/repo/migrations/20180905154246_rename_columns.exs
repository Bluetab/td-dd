defmodule TdDq.Repo.Migrations.RenameColumns do
  use Ecto.Migration

  def up do
    rename table(:rule_implementations), :quality_control_id, to: :rule_id
    rename table(:rule_implementations), :quality_rule_type_id, to: :rule_type_id
  end

  def down do
    rename table(:rule_implementations), :rule_id, to: :quality_control_id
    rename table(:rule_implementations), :rule_type_id, to: :quality_rule_type_id
  end
end
