defmodule TdDd.Repo.Migrations.AddSourceIdToStructures do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      add(:source_id, :integer, default: nil, null: true)
    end
  end
end
