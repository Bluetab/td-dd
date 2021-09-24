defmodule TdDd.Grants.GrantRequestStatus do
  @moduledoc """
  Ecto Schema module for Grant Request Status.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Grants.GrantRequest

  schema "grant_request_status" do
    field(:status, :string)

    belongs_to(:grant_request, GrantRequest)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:status])
    |> validate_inclusion(:status, ["pending", "approved", "rejected", "processing", "processed"])
  end
end
