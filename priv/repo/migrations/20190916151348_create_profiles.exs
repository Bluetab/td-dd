defmodule TdDd.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :value, :map, null: false
      add :data_structure_id, references(:data_structures), null: false

      timestamps()
    end

  end
end
