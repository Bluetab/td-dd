defmodule TdDd.DataStructures.DataStructureType do
  @moduledoc """
  Ecto Schema module for Data Structure Type.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_structure_types" do
    field :structure_type, :string
    field :template_id, :integer
    field :translation, :string
    field :metadata_fields, :map

    timestamps()
  end

  @doc false
  def changeset(data_structure_type, attrs) do
    data_structure_type
    |> cast(attrs, [:structure_type, :translation, :template_id, :metadata_fields])
    |> validate_required([:structure_type, :template_id])
    |> unique_constraint(:structure_type)
  end
end
