defmodule TdDd.Repo.Migrations.AddSourceIdToStructures do
  use Ecto.Migration

  def up do
    alter table(:data_structures) do
      add(:source_id, :integer, default: nil, null: true)
    end
  end

  def down do
    alter table(:data_structures) do
      remove(:source_id, :integer, default: nil, null: true)
    end
  end
end
