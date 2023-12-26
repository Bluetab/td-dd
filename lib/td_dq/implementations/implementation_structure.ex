defmodule TdDq.Implementations.ImplementationStructure do
  @moduledoc """
  Ecto Schema module for Implementations and DataStructures relation
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDq.Implementations.Implementation

  schema "implementations_structures" do
    belongs_to(:implementation, Implementation)
    belongs_to(:data_structure, DataStructure)

    field(:deleted_at, :utc_datetime_usec)
    field(:type, Ecto.Enum, values: [:dataset, :population, :validation])

    has_one(:source, through: [:data_structure, :source])

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(implementation_structure, attrs, implementation, data_structure) do
    implementation_structure
    |> cast(attrs, [:type])
    |> validate_required(:type)
    |> put_assoc(:data_structure, data_structure)
    |> put_assoc(:implementation, implementation)
    |> unique_constraint([:implementation_id, :data_structure_id, :type],
      name: :implementations_structures_implementation_structure_type
    )
  end

  @doc false
  def delete_changeset(implementation_structure) do
    implementation_structure
    |> cast(%{deleted_at: DateTime.utc_now()}, [:deleted_at])
  end
end
