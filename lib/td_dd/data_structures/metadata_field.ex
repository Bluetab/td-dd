defmodule TdDd.DataStructures.MetadataField do
  @moduledoc """
  Ecto Schema module for Data Structure Type Field.
  """

  use Ecto.Schema

  alias TdDd.DataStructures.DataStructureType

  @type t :: %__MODULE__{}

  schema "metadata_fields" do
    field(:name, :string)
    belongs_to(:data_structure_type, DataStructureType)
    timestamps(type: :utc_datetime_usec)
  end
end
