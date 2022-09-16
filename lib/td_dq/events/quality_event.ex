defmodule TdDq.Events.QualityEvent do
  @moduledoc "Event entity"

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Executions.Execution

  schema "quality_events" do
    belongs_to(:execution, Execution)
    has_one(:group, through: [:execution, :group])
    field(:type, :string)
    field(:message, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :message, :execution_id])
    |> validate_required(:execution_id)
    |> validate_length(:message, max: 1_000)
  end

  def create_changeset(%{} = params) do
    %__MODULE__{}
    |> cast(params, [:type, :message, :execution_id])
    |> validate_required(:execution_id)
    |> validate_length(:message, max: 1_000)
  end
end
