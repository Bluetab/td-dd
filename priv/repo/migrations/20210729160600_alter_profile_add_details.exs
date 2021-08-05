defmodule TdDd.Repo.Migrations.AddProfileDetail do
  use Ecto.Migration

  def change do
    alter table("profiles") do
      add(:max, :text)
      add(:min, :text)
      add(:most_frequent, {:array, :map})
      add(:null_count, :integer)
      add(:patterns, {:array, :map})
      add(:total_count, :integer)
      add(:unique_count, :integer)
    end
  end
end
