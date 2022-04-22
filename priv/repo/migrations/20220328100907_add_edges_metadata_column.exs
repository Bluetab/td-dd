defmodule TdDd.Repo.Migrations.AddEdgesMetadataColumn do
  use Ecto.Migration

  def change do
    alter table("edges") do
      add(:metadata, :map)
    end
  end
end
