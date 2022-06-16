defmodule TdDd.DataStructures.StructureMetadata do
  @moduledoc """
  Ecto schema module for mutable structure metadata
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDfLib.Validation

  schema "structure_metadata" do
    field(:version, :integer, default: 0)
    field(:fields, :map)
    field(:deleted_at, :utc_datetime_usec)
    belongs_to(:data_structure, DataStructure)
    has_one(:current_version, through: [:data_structure, :current_version])

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:version, :fields, :data_structure_id, :deleted_at])
    |> validate_required([:version, :fields, :data_structure_id])
    |> validate_change(:fields, &Validation.validate_safe/2)
    |> unique_constraint([:data_structure_id, :version])
  end
end
