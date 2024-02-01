defmodule TdDd.Lineage.Units.Event do
  @moduledoc """
  Ecto schema module for events associated with a `Unit`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Lineage.Units.Unit
  alias TdDfLib.Validation

  schema "unit_events" do
    belongs_to(:unit, Unit)

    field(:event, :string)
    field(:info, :map)

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  defp changeset(%__MODULE__{} = event, %{} = params) do
    event
    |> cast(params, [:unit_id, :event, :info])
    |> put_change(:inserted_at, DateTime.utc_now())
    |> validate_inclusion(:event, ["LoadStarted", "LoadFailed", "LoadSucceeded", "Deleted"])
    |> validate_required([:unit_id, :event, :inserted_at])
    |> validate_change(:info, &Validation.validate_safe/2)
  end
end
