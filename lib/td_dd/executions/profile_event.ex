defmodule TdDd.Executions.ProfileEvent do
  @moduledoc "Event entity"

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Executions.ProfileExecution

  schema "profile_events" do
    belongs_to(:profile_execution, ProfileExecution)
    field(:type, :string)
    field(:message, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :message, :profile_execution_id])
    |> validate_length(:message, max: 1_000)
  end

  def create_changeset(%{} = params) do
    %__MODULE__{}
    |> cast(params, [:type, :message, :profile_execution_id])
    |> validate_required(:profile_execution_id)
    |> validate_length(:message, max: 1_000)
  end
end
