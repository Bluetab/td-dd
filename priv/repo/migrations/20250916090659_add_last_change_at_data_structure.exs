defmodule TdDd.Repo.Migrations.AddLastChangeAtDataStructure do
  use Ecto.Migration

  def up do
    alter table(:data_structures) do
      add(:last_change_at, :timestamp, null: true)
    end

    flush()

    execute("""
    UPDATE data_structures
    SET last_change_at = updated_at
    """)
  end

  def down do
    alter table(:data_structures) do
      remove(:last_change_at)
    end
  end
end
