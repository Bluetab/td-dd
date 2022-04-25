defmodule TdDd.Repo.Migrations.AlterProfileCounts do
  use Ecto.Migration

  def change do
    alter table("profiles") do
      modify(:null_count, :bigint, from: :integer)
      modify(:total_count, :bigint, from: :integer)
      modify(:unique_count, :bigint, from: :integer)
    end
  end
end
