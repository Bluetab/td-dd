defmodule TdDd.DataStructures.DataStructureRelation do
  @moduledoc """
  Ecto Schema module for Data Structure Relations
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationType

  schema "data_structure_relations" do
    belongs_to :parent, DataStructureVersion
    belongs_to :child, DataStructureVersion
    belongs_to :relation_type, RelationType
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%DataStructureRelation{} = data_structure_relation, params) do
    data_structure_relation
    |> cast(params, [:parent_id, :child_id])
    |> validate_required([:parent_id, :child_id, :relation_type_id])
    |> check_constraint(
      :parent_id,
      name: :avoid_structure_relation_itself,
      message: "Structure must not have relations with itself"
    )
  end

  def update_changeset(%DataStructureRelation{} = data_structure_relation, params) do
    cast(data_structure_relation, params, [:parent_id, :child_id, :relation_type_id])
  end
end
