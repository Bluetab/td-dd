defmodule TdDd.Repo.Migrations.MigrateDraftToSimpleTypeImplementation do
  use Ecto.Migration

  def up do
    execute("UPDATE rule_implementations
        SET implementation_type = 'basic'
        WHERE implementation_type = 'draft'")
  end

  def down do
    execute("UPDATE rule_implementations
        SET implementation_type = 'draft'
        WHERE implementation_type = 'basic'")
  end
end
