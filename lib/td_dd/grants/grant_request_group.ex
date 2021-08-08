defmodule TdDd.Grants.GrantRequestGroup do
  @moduledoc """
  Ecto Schema module for Grant Request Group.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.Grants.GrantRequest

  schema "grant_request_groups" do
    field :request_date, :utc_datetime_usec
    field :type, :string
    field :user_id, :integer

    has_many(:requests, GrantRequest)

    timestamps()
  end

  @doc false
  def changeset(grant_request_group, attrs) do
    grant_request_group
    |> cast(attrs, [:request_date, :user_id, :type])
    |> cast_assoc(:requests)
    |> validate_required([:request_date, :user_id])
  end

  @doc false
  def update_changeset(grant_request_group, attrs) do
    grant_request_group
    |> cast(attrs, [:request_date, :type])
    |> validate_required([:request_date])
  end
end
