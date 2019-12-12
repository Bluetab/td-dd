defmodule TdDq.Repo.Migrations.RuleTypeNullable do
  use Ecto.Migration

  def change do
      execute("ALTER TABLE rules ALTER COLUMN rule_type_id DROP NOT NULL")
  end
end
