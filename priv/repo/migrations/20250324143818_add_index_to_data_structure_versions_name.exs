defmodule TdDd.Repo.Migrations.AddIndexToDataStructureVersionsName do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:data_structure_versions, [:name]))
  end
end
