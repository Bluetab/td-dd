defmodule TdDd.DataStructures.DataStructureTag do
  @moduledoc """
  Ecto Schema module for Data Structure Tag.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructuresTags

  schema "data_structure_tags" do
    field :name, :string
    field :domain_ids, {:array, :integer}, default: []
    field :structure_count, :integer, virtual: true

    many_to_many(:tagged_structures, DataStructure, join_through: DataStructuresTags)

    timestamps()
  end

  def changeset(data_structure_tag, params) do
    data_structure_tag
    |> cast(params, [:name, :domain_ids])
    |> validate_required(:name)
    |> unique_constraint(:name)
  end
end
