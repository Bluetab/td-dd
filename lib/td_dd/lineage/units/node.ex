defmodule TdDd.Lineage.Units.Node do
  @moduledoc """
  Ecto schema module for graph nodes.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Lineage.Units.Unit
  alias TdDfLib.Validation

  schema "nodes" do
    field(:external_id, :string)
    field(:type, :string)
    field(:label, :map, default: %{})
    field(:deleted_at, :utc_datetime_usec)
    field(:domain_ids, {:array, :integer}, virtual: true)
    field(:parent_ids, {:array, :integer}, virtual: true)

    belongs_to(:structure, DataStructure)

    many_to_many(:units, Unit, join_through: "units_nodes")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = node, %{} = params) do
    node
    |> cast(params, [:external_id, :type, :label, :structure_id])
    |> validate_required([:external_id, :type, :label])
    |> validate_change(:label, &Validation.validate_safe/2)
    |> unique_constraint(:external_id)
  end
end
