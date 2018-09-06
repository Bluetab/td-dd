defmodule TdDq.Repo.Migrations.DeleteIndexes do
  use Ecto.Migration

  def up do
    drop index(:quality_rules, [:quality_control_id])
    drop unique_index(:quality_rule_types, [:name])
  end

  def down do
  end

end
