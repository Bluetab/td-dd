defmodule TdDq.Repo.Migrations.RemoveDescriptionFromRuleImplementation do
  use Ecto.Migration

  def up do
    alter table(:rule_implementations) do
      remove(:description)
    end
  end

  def down do
    alter table(:rule_implementations) do
      add(:description, :string, null: true, size: 500)
    end
  end
end
