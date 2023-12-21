defmodule TdCx.Jobs.Job do
  @moduledoc """
  Ecto Schema module for jobs
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Events.Event
  alias TdCx.Sources.Source
  alias TdDfLib.Validation

  schema "jobs" do
    field(:external_id, Ecto.UUID, autogenerate: true)
    field(:type, :string)
    field(:parameters, :map, default: %{})
    belongs_to(:source, Source)
    has_many(:events, Event)
    # Note: updated_at is updated with most recent event's inserted_at
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:source_id, :type, :parameters])
    |> validate_required(:source_id)
    |> validate_change(:parameters, &Validation.validate_safe/2)
  end
end
