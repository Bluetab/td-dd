defmodule TdDd.DataStructures.DataStructureTag do
  @moduledoc """
  Ecto Schema module for Data Structure Tag.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_structure_tags" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(data_structure_tag, attrs) do
    data_structure_tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
