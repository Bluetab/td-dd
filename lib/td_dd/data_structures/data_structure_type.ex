defmodule TdDd.DataStructures.DataStructureType do
  @moduledoc """
  Ecto Schema module for Data Structure Type.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_structure_types" do
    field(:structure_type, :string)
    field(:template_id, :integer)
    field(:translation, :string)

    timestamps()
  end

  def changeset(data_structure_type, params) do
    data_structure_type
    |> cast(params, [:structure_type, :translation, :template_id])
    |> validate_required([:structure_type, :template_id])
    |> unique_constraint(:structure_type)
  end
end
