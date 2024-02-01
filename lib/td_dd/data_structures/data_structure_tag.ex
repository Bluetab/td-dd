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
    field :description, :string
    field :domain_ids, {:array, :integer}, default: []
    field :structure_count, :integer, virtual: true

    many_to_many(:tagged_structures, DataStructure, join_through: DataStructuresTags)

    timestamps()
  end

  def changeset(data_structure_tag, params) do
    data_structure_tag
    |> cast(params, [:name, :domain_ids, :description])
    |> validate_required(:name)
    |> unique_constraint(:name)
    |> validate_length(:description, max: 1_000, message: "max.length.1000")
  end
end
