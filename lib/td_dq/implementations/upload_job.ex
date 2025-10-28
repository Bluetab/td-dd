defmodule TdDq.Implementations.UploadJob do
  @moduledoc "File Bulk Update Job entity"

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Implementations.UploadEvent

  schema "implementation_upload_jobs" do
    field(:user_id, :integer)
    field(:hash, :string)
    field(:filename, :string)

    field(:latest_status, :string, virtual: true)
    field(:latest_event_at, :utc_datetime_usec, virtual: true)
    field(:latest_event_response, :map, virtual: true)

    has_many(:events, UploadEvent, foreign_key: :job_id)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [
      :user_id,
      :hash,
      :filename
    ])
    |> validate_required([:user_id, :hash, :filename])
  end
end
