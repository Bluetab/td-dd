defmodule TdDd.Repo.Migrations.UpdateDataStructureVersionHashes do
  use Ecto.Migration

  def change do
    execute("update data_structure_versions set hash = null, lhash = null, ghash = null;")
  end
end
