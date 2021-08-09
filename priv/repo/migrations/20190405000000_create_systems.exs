defmodule TdDd.Repo.Migrations.CreateSystems do
  use Ecto.Migration

  def change do
    create table("systems") do
      add(:name, :string, null: false)
      add(:external_id, :string, null: false)

      timestamps()
    end

    create unique_index("systems", [:external_id])
  end
end
