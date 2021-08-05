defmodule TdDd.Repo.Migrations.CreateDataStructureTypes do
  use Ecto.Migration

  def change do
    create table(:data_structure_types) do
      add :structure_type, :string
      add :translation, :string
      add :template_id, :integer

      timestamps()
    end

    create unique_index(:data_structure_types, [:structure_type])
  end
end
