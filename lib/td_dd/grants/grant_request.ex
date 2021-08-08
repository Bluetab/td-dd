defmodule TdDd.Grants.GrantRequest do
  @moduledoc """
  Ecto Schema module for Grant Request.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.GrantRequestGroup
  alias TdDfLib.Validation

  schema "grant_requests" do
    field :filters, :map
    field :metadata, :map

    belongs_to(:grant_request_group, GrantRequestGroup)
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  @doc false
  def changeset(grant_request, attrs) do
    type = Map.get(attrs, "group_type")

    grant_request
    |> cast(attrs, [
      :grant_request_group_id,
      :data_structure_id,
      :filters,
      :metadata
    ])
    |> validate_content(%{type: type})
  end

  @doc false
  def changeset(attrs, grant_request_group, data_structure) do
    %__MODULE__{}
    |> cast(attrs, [:filters, :metadata])
    |> put_assoc(:data_structure, data_structure)
    |> put_assoc(:grant_request_group, grant_request_group)
    |> validate_content(grant_request_group)
    |> validate_required([:grant_request_group, :data_structure])
  end

  defp validate_content(%{} = changeset, %{type: nil}), do: changeset

  defp validate_content(%{} = changeset, %{type: template_name}) when is_binary(template_name) do
    changeset
    |> validate_required(:metadata)
    |> validate_change(:metadata, Validation.validator(template_name))
  end

  defp validate_content(%{} = changeset, _), do: changeset

  @doc false
  def update_changeset(grant_request, attrs) do
    grant_request
    |> cast(attrs, [:filters, :metadata])
  end
end
