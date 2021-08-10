defmodule TdDd.Repo.Migrations.CreateDataStructureTags do
  use Ecto.Migration

  def change do
    create table("data_structure_tags") do
      add :name, :string

      timestamps()
    end

    create unique_index("data_structure_tags", [:name])
  end
end
