defmodule TdDd.DataStructures.StructureMetadata do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure

  schema "structure_metadata" do
    field(:version, :integer, default: 0)
    field(:fields, :map)
    field(:deleted_at, :utc_datetime)
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  @doc false
  def changeset(structure_metadata, attrs) do
    structure_metadata
    |> cast(attrs, [:version, :fields, :data_structure_id, :deleted_at])
    |> validate_required([:version, :fields, :data_structure_id])
  end
end
