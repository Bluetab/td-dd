defmodule TdDd.DataStructures.DataStructureRelation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion

  schema "data_structure_relations" do
    belongs_to(:parent, DataStructureVersion)
    belongs_to(:child, DataStructureVersion)
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%DataStructureRelation{} = data_structure_relation, attrs) do
    data_structure_relation
    |> cast(attrs, [
      :parent_id,
      :child_id
    ])
    |> validate_required([:parent_id, :child_id])
  end

  @doc false
  def update_changeset(%DataStructureRelation{} = data_structure_relation, attrs) do
    data_structure_relation
    |> cast(attrs, [:parent_id, :child_id])
  end
end
