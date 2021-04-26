defmodule TdDd.Repo.Migrations.UpdateDataStructureVersionHashes do
  use Ecto.Migration

  def up do
    execute("update data_structure_versions set hash = null, lhash = null, ghash = null;")
  end

  def down, do: :ok
end
