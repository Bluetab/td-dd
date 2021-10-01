defmodule TdDd.Grants.GrantRequest do
  @moduledoc """
  Ecto Schema module for Grant Request.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.GrantRequestStatus
  alias TdDfLib.Validation

  @type t :: %__MODULE__{}

  schema "grant_requests" do
    field(:filters, :map)
    field(:metadata, :map)
    field(:current_status, :string, virtual: true)
    field(:domain_id, :integer)
    # updated_at is derived from most recent status
    field(:updated_at, :utc_datetime_usec, virtual: true)

    belongs_to(:group, GrantRequestGroup)
    belongs_to(:data_structure, DataStructure)

    has_many(:status, GrantRequestStatus)
    has_many(:approvals, GrantRequestApproval)
    field(:pending_roles, {:array, :string}, virtual: true)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%__MODULE__{} = struct, params, template_name) do
    struct
    |> cast(params, [:filters, :metadata, :data_structure_id])
    |> validate_content(template_name)
    |> foreign_key_constraint(:data_structure_id)
  end

  defp validate_content(%{} = changeset, template_name) when is_binary(template_name) do
    changeset
    |> validate_required(:metadata)
    |> validate_change(:metadata, Validation.validator(template_name))
  end

  defp validate_content(%{} = changeset, nil = _no_template_name), do: changeset
end
