defmodule TdDd.DataStructures.DataStructuresTags do
  @moduledoc """
  Relation between a structure and tag
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureTag

  schema "data_structures_tags" do
    belongs_to(:data_structure, DataStructure)
    belongs_to(:data_structure_tag, DataStructureTag)
    field(:comment, :string)
    field(:resource, :map, virtual: true, default: %{})
    field(:tag, :string, virtual: true)
    field(:domain_ids, {:array, :integer}, virtual: true, default: [])

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  def changeset(tag_link, attrs) do
    tag_link
    |> cast(attrs, [:comment])
    |> validate_length(:comment, max: 1_000, message: "max.length.1000")
  end

  def put_data_structure(changeset, data_structure) do
    put_assoc(changeset, :data_structure, data_structure)
  end

  def put_data_structure_tag(changeset, data_structure_tag) do
    put_assoc(changeset, :data_structure_tag, data_structure_tag)
  end
end
