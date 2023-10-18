defmodule TdDd.Grants.GrantRequest do
  @moduledoc """
  Ecto Schema module for Grant Request.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.GrantRequestStatus
  alias TdDfLib.Validation

  @type t :: %__MODULE__{}

  schema "grant_requests" do
    field(:filters, :map)
    field(:metadata, :map)
    field(:current_status, :string, virtual: true)
    field(:approved_by, {:array, :string}, virtual: true)
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

  defimpl Elasticsearch.Document do
    alias TdCache.TemplateCache
    alias TdDd.Grants.GrantRequest
    alias TdDfLib.Format

    @impl Elasticsearch.Document
    def id(%GrantRequest{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%{data_structure_version: nil}), do: %{}

    def encode(
          %{
            data_structure_version: %DataStructureVersion{} = dsv,
            group: %GrantRequestGroup{} = group
          } = grant_request
        ) do
      template =
        TemplateCache.get_by_name!(group.type) ||
          %{content: []}

      user = grant_request.user
      created_by = grant_request.created_by

      metadata =
        grant_request
        |> Map.get(:metadata)
        |> Format.search_values(template)

      %{
        id: grant_request.id,
        current_status: grant_request.current_status,
        approved_by: grant_request.approved_by,
        domain_ids: grant_request.domain_ids,
        user_id: group.user_id,
        user: %{
          id: user.id,
          user_name: user.user_name,
          email: Map.get(user, :email, ""),
          full_name: user_full_name(user)
        },
        created_by_id: group.created_by_id,
        created_by: %{
          id: created_by.id,
          email: Map.get(created_by, :email, ""),
          user_name: created_by.user_name,
          full_name: user_full_name(created_by)
        },
        data_structure_id: grant_request.data_structure_id,
        data_structure_version: Elasticsearch.Document.encode(dsv),
        inserted_at: grant_request.inserted_at,
        type: group.type,
        metadata: metadata,
        modification_grant_id: group.modification_grant_id
      }
    end

    defp user_full_name(%{full_name: full_name}) do
      full_name
    end

    defp user_full_name(_), do: ""
  end
end
