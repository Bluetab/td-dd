defmodule TdDd.Lineage.Units.Edge do
  @moduledoc """
  Ecto schema module for graph edges.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Lineage.Units.Node
  alias TdDd.Lineage.Units.Unit
  alias TdDfLib.Validation

  schema "edges" do
    belongs_to(:unit, Unit)
    belongs_to(:start, Node)
    belongs_to(:end, Node)

    field(:type, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = edge, %{} = params) do
    edge
    |> cast(params, [:unit_id, :start_id, :end_id, :type, :metadata])
    |> validate_required([:unit_id, :start_id, :end_id, :type, :metadata])
    |> validate_change(:metadata, &Validation.validate_safe/2)
    |> unique_constraint([:unit_id, :start_id, :end_id])
  end
end
