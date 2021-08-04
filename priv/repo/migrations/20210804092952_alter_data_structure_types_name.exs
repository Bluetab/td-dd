defmodule TdDd.Repo.Migrations.AlterDataStructureTypesName do
  use Ecto.Migration

  def change do
    drop unique_index(:data_structure_types, [:structure_type])
    rename table("data_structure_types"), :structure_type, to: :name
    create unique_index(:data_structure_types, [:name])
  end
end
