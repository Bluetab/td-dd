defmodule TdDd.Grants.GrantRequestStatus do
  @moduledoc """
  Ecto Schema module for Grant Request Status.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Grants.GrantRequest

  schema "grant_request_status" do
    field(:status, :string)
    field(:previous_status, :string, virtual: true)
    field(:reason, :string)
    field(:user_id, :integer)

    belongs_to(:grant_request, GrantRequest)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @valid_statuses [
    "pending",
    "approved",
    "rejected",
    "processing",
    "processed",
    "failed",
    "cancelled"
  ]
  @valid_status_changes [
    {"approved", "processing"},
    {"processing", "processed"},
    {"processing", "failed"},
    {"pending", "cancelled"},
    {"approved", "cancelled"}
  ]

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> validate_required(:user_id)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_status()
  end

  defp validate_status(changeset) do
    previous_status = get_field(changeset, :previous_status)
    status = get_field(changeset, :status)

    if validate_status_change(previous_status, status) do
      changeset
    else
      add_error(changeset, :status, "invalid status change")
    end
  end

  defp validate_status_change(nil = _previous_status, _status), do: true

  defp validate_status_change(previous_status, status) do
    {previous_status, status} in @valid_status_changes
  end
end
