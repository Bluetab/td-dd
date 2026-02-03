defmodule Truedat.Audit.UploadEvents.UploadEvent do
  @moduledoc "File Upload Event entity"

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias Truedat.Audit.UploadJobs.UploadJob

  @valid_statuses ["PENDING", "FAILED", "STARTED", "COMPLETED", "ERROR", "INFO"]

  schema "upload_events" do
    belongs_to(:job, UploadJob)
    field(:response, :map)
    field(:status, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [
      :job_id,
      :response,
      :status
    ])
    |> validate_required([:job_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_change(:response, &Validation.validate_safe/2)
  end
end
