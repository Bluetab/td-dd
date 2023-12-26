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

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :message, :job_id])
    |> validate_required(:job_id)
    |> validate_length(:message, max: 1_000)
  end
end
