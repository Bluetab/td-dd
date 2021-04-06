defmodule TdDd.Repo.Migrations.AddDataStructureVersionUniqueIndex do
  use Ecto.Migration

  def change do
    create(unique_index("data_structure_versions", [:data_structure_id, :version]))
  end
end
