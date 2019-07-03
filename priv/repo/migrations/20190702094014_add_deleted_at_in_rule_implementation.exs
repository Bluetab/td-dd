defmodule TdDq.Repo.Migrations.AddDeletedAtInRuleImplementation do
  use Ecto.Migration

  def up do
    alter(table(:rule_implementations), do: add(:deleted_at, :utc_datetime_usec))
    drop unique_index(:rule_implementations, [:implementation_key])
    create unique_index(:rule_implementations, [:implementation_key, :deleted_at], where: "deleted_at IS NULL")
  end

  def down do
    alter(table(:rule_implementations), do: remove(:deleted_at))
    create unique_index(:rule_implementations, [:implementation_key])
  end
end
