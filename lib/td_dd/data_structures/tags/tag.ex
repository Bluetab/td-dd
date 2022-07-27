defmodule TdDd.DataStructures.Tags.Tag do
  @moduledoc """
  Ecto Schema module for Data Structure Tag.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.Tags.StructureTag

  schema "tags" do
    field :name, :string
    field :description, :string
    field :domain_ids, {:array, :integer}, default: []
    field :structure_count, :integer, virtual: true

    has_many :structures_tags, StructureTag

    timestamps type: :utc_datetime_usec
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :domain_ids, :description])
    |> validate_required(:name)
    |> unique_constraint(:name)
    |> validate_length(:description, max: 1_000)
  end
end
