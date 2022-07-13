defmodule TdDd.DataStructures.DataStructuresTags do
  @moduledoc """
  Relation between a structure and tag
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureTag

  schema "data_structures_tags" do
    field :comment, :string
    field :resource, :map, virtual: true, default: %{}
    field :tag, :string, virtual: true
    field :domain_ids, {:array, :integer}, virtual: true, default: []
    field :inherit, :boolean, default: false

    belongs_to :data_structure, DataStructure
    belongs_to :data_structure_tag, DataStructureTag

    timestamps type: :utc_datetime_usec
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:comment, :inherit])
    |> validate_length(:comment, max: 1_000)
  end
end
