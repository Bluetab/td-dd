defmodule TdDd.Repo.Migrations.AddInternalImplementations do
  use Ecto.Migration

  def up do
    alter table(:rule_implementations) do
      add(:executable, :boolean, default: true, null: false)
    end
  end

  def down do
    alter table(:rule_implementations) do
      remove(:executable, :boolean)
    end
  end
end
