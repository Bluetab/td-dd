defmodule TdDd.Grants.GrantRequestGroup do
  @moduledoc """
  Ecto Schema module for Grant Request Group.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.Grants.GrantRequest

  schema "grant_request_groups" do
    field :type, :string
    field :user_id, :integer

    has_many(:requests, GrantRequest)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:type])
    |> cast_requests()
  end

  defp cast_requests(changeset) do
    cast_assoc(changeset, :requests,
      required: true,
      with: {GrantRequest, :changeset, [fetch_field!(changeset, :type)]}
    )
  end
end