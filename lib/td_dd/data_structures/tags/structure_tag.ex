defmodule TdDd.DataStructures.Tags.StructureTag do
  @moduledoc """
  Relation between a structure and tag
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Tags.Tag

  schema "structures_tags" do
    field :comment, :string
    field :resource, :map, virtual: true, default: %{}
    field :tag_name, :string, virtual: true
    field :domain_ids, {:array, :integer}, virtual: true, default: []
    field :inherit, :boolean, default: false
    field :inherited, :boolean, virtual: true

    belongs_to :data_structure, DataStructure
    belongs_to :tag, Tag

    timestamps type: :utc_datetime_usec
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:comment, :inherit])
    |> validate_required(:inherit)
    |> validate_length(:comment, max: 1_000)
  end
end
