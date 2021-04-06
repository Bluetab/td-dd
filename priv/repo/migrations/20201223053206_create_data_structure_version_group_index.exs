defmodule TdDd.Repo.Migrations.CreateDataStructureVersionGroupIndex do
  use Ecto.Migration

  def change do
    create index("data_structure_versions", [:group])
  end
end
