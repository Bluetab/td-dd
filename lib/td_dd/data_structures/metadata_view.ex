defmodule TdDd.DataStructures.MetadataView do
  @moduledoc """
  Ecto Schema module for metadata views in structure types
  """

  use Ecto.Schema

  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:fields, {:array, :string})
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :fields])
    |> validate_required([:name, :fields])
  end
end
