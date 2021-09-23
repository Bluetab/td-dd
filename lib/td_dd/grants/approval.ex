defmodule TdDd.Grants.Approval do
  @moduledoc """
  Ecto Schema module for Grant Request approvals.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.TaxonomyCache
  alias TdDd.Grants.GrantRequest

  schema "grant_request_approvals" do
    field :user_id, :integer
    field :domain_id, :integer
    field :role, :string
    field :is_rejection, :boolean, default: false
    field :comment, :string
    field :user, :map, virtual: true
    field :domain, :map, virtual: true
    field :current_status, :string, virtual: true

    belongs_to :grant_request, GrantRequest

    timestamps type: :utc_datetime_usec, updated_at: false
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:comment, :domain_id, :is_rejection, :role])
    |> validate_required([
      :current_status,
      :domain_id,
      :grant_request_id,
      :is_rejection,
      :role,
      :user_id
    ])
    # validate_inclusion won't work here, current_status is not cast in the params
    |> validate_field(:current_status, "pending")
    |> maybe_validate_approver()
    |> foreign_key_constraint(:grant_request_id)
    |> unique_constraint([:grant_request_id, :role])
  end

  defp validate_field(changeset, field, expected_value) do
    case fetch_field!(changeset, field) do
      ^expected_value ->
        changeset

      _ ->
        add_error(changeset, field, "is invalid", validation: :inclusion, enum: [expected_value])
    end
  end

  defp maybe_validate_approver(%{valid?: false} = changeset), do: changeset

  defp maybe_validate_approver(changeset) do
    with domain_id <- fetch_field!(changeset, :domain_id),
         user_id <- fetch_field!(changeset, :user_id),
         role <- fetch_field!(changeset, :role),
         true <- TaxonomyCache.has_role?(domain_id, role, user_id) do
      changeset
    else
      _ -> add_error(changeset, :user_id, "invalid role")
    end
  end
end