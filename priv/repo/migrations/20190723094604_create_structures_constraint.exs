defmodule TdDd.Repo.Migrations.CreateStructuresConstraint do
  use Ecto.Migration
  import Ecto.Query
  alias TdDd.Repo
  alias TdDd.DataStructures.DataStructureRelation

  def change do
    from(dsr in DataStructureRelation, where: dsr.parent_id == dsr.child_id)
    |> Repo.delete_all()

    create constraint(:data_structure_relations, :avoid_structure_relation_itself, check: "parent_id != child_id")
  end
end
