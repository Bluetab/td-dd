defmodule TdDd.Repo.Migrations.CreateGraphs do
  use Ecto.Migration

  def change do
    create table("graphs") do
      add(:hash, :string)
      add(:data, :map)

      timestamps()
    end

    create unique_index("graphs", [:hash])
  end
end
