defmodule TdCx.Sources.Jobs.Job do
  @moduledoc "Job entity"
  use Ecto.Schema
  import Ecto.Changeset

  alias TdCx.Sources.Events.Event
  alias TdCx.Sources.Source

  schema "jobs" do
    belongs_to(:source, Source)
    has_many(:events, Event)
    field(:external_id, Ecto.UUID, autogenerate: true)

    timestamps()
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [:source_id])
    |> validate_required([:source_id])
  end
end
