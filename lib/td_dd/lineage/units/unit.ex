defmodule TdDd.Lineage.Units.Unit do
  @moduledoc """
  Ecto schema module for graph nodes.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Lineage.Units.{Edge, Event, Node}

  schema "units" do
    field(:name, :string)
    field(:deleted_at, :utc_datetime_usec)
    field(:status, :map, virtual: true)

    has_many(:edges, Edge)
    has_many(:events, Event)

    many_to_many(:nodes, Node, join_through: "units_nodes")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = collection, %{} = params) do
    collection
    |> cast(params, [:name, :deleted_at, :updated_at])
    |> validate_required([:name])
    |> unset_deleted_at()
    |> unique_constraint(:name)
  end

  defp unset_deleted_at(changeset) do
    case fetch_change(changeset, :deleted_at) do
      {:ok, _} -> changeset
      :error -> put_change(changeset, :deleted_at, nil)
    end
  end
end
