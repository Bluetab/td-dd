defmodule TdDd.DataStructures.MetadataField do
  @moduledoc """
  Ecto Schema module for Data Structure Type Field.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructureType

  @type t :: %__MODULE__{}

  schema "metadata_fields" do
    belongs_to(:data_structure_type, DataStructureType)
    field(:name, :string)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name, :data_structure_type_id])
    |> unique_constraint([:name, :data_structure_type_id])
  end
end
