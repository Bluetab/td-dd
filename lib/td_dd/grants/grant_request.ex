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
    field(:status_reason, :string, virtual: true)
    field(:domain_ids, {:array, :integer}, default: [])
    # updated_at is derived from most recent status
    field(:updated_at, :utc_datetime_usec, virtual: true)

    belongs_to(:group, GrantRequestGroup)
    belongs_to(:data_structure, DataStructure)

    has_many(:status, GrantRequestStatus)
    has_many(:approvals, GrantRequestApproval)
    field(:pending_roles, {:array, :string}, virtual: true)
    field(:all_pending_roles, {:array, :string}, virtual: true)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%__MODULE__{} = struct, params, template_name) do
    struct
    |> cast(params, [:filters, :metadata, :data_structure_id])
    |> maybe_put_identifier(struct, template_name)
    |> validate_content(template_name)
    |> validate_change(:filters, &Validation.validate_safe/2)
    |> validate_change(:metadata, &Validation.validate_safe/2)
    |> foreign_key_constraint(:data_structure_id)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{metadata: old_content} = _grant_request,
         template_name
       )
       when old_content != nil do
    maybe_put_identifier_aux(changeset, old_content, template_name)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{} = _grant_request,
         template_name
       ) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{metadata: changeset_content}} = changeset,
         old_content,
         template_name
       ) do
    new_content =
      TdDfLib.Format.maybe_put_identifier(changeset_content, old_content, template_name)

    put_change(changeset, :metadata, new_content)
  end

  defp maybe_put_identifier_aux(changeset, _old_content, _template_name) do
    changeset
  end

  defp validate_content(%{} = changeset, template_name) when is_binary(template_name) do
    changeset
    |> validate_required(:metadata)
    |> validate_change(:metadata, Validation.validator(template_name))
  end

  defp validate_content(%{} = changeset, nil = _no_template_name), do: changeset
end
