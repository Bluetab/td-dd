defmodule TdDd.Grants.GrantRequestGroup do
  @moduledoc """
  Ecto Schema module for Grant Request Group.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest

  schema "grant_request_groups" do
    field(:type, :string)
    field(:user_id, :integer)
    field(:user, :map, virtual: true)
    field(:created_by_id, :integer)

    has_many(:requests, GrantRequest, foreign_key: :group_id)
    belongs_to(:modification_grant, Grant)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = struct, params, %Grant{} = modification_grant) do
    struct
    |> changeset(params, nil)
    |> put_assoc(:modification_grant, modification_grant)
  end

  def changeset(%__MODULE__{} = struct, params, _) do
    struct
    |> cast(params, [:type, :user_id, :created_by_id])
    |> cast_requests()
  end

  defp cast_requests(changeset) do
    type = fetch_field!(changeset, :type)

    cast_assoc(changeset, :requests,
      required: true,
      with: &GrantRequest.changeset(&1, &2, type)
    )
  end
end
