defmodule TdDd.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :value, :map, null: false
      add :data_structure_id, references(:data_structures, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:profiles, [:data_structure_id])
  end
end
