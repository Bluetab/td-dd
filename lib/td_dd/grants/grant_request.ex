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

    timestamps(type: :utc_datetime_usec)
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