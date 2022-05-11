defmodule TdDd.Repo.Migrations.MigrateRuleDeletedAtStateToImplementation do
  use Ecto.Migration

  def up do
    execute("""
      UPDATE rule_implementations ri
      SET deleted_at = r.deleted_at
      FROM rules r
      WHERE ri.rule_id = r.id
        AND ri.deleted_at IS NULL
      ;
    """)
  end

  def down, do: :ok # This migration is irreversible
end
