defmodule TdCx.Events.Event do
  @moduledoc "Event entity"

  use Ecto.Schema
  import Ecto.Changeset

  alias TdCx.Jobs.Job

  schema "events" do
    belongs_to(:job, Job)
    field(:type, :string)
    field(:message, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:type, :message, :job_id])
    |> validate_required([:job_id])
  end
end
