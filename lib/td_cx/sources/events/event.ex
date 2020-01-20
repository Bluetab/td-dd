defmodule TdCx.Sources.Events.Event do
  @moduledoc "Event entity"

  use Ecto.Schema
  import Ecto.Changeset

  alias TdCx.Sources.Jobs.Job

  schema "events" do
    belongs_to(:job, Job)
    field(:date, :utc_datetime_usec)
    field(:type, :string)
    field(:message, :string)

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:date, :type, :message, :job_id])
    |> validate_required([:job_id])
  end
end
