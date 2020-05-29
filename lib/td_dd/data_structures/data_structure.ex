defmodule TdDd.DataStructures.DataStructure do
  @moduledoc """
  Ecto Schema module for Data Structures.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.Content
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Systems.System

  @audit_fields [:last_change_by]

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    has_many(:versions, DataStructureVersion)
    has_many(:metadata_versions, StructureMetadata)
    has_one(:profile, Profile)

    field(:confidential, :boolean)
    field(:df_content, :map)
    field(:domain_id, :integer)
    field(:external_id, :string)
    field(:last_change_by, :integer)

    timestamps(type: :utc_datetime)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [
      :confidential,
      :df_content,
      :domain_id,
      :external_id,
      :system_id
    ])
    |> put_audit(params)
    |> validate_required([
      :external_id,
      :last_change_by,
      :system_id
    ])
    |> validate_change(:df_content, Content.validator(data_structure))
  end

  def update_changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [:confidential, :df_content])
    |> put_audit(params)
    |> validate_change(:df_content, Content.validator(data_structure))
  end

  def merge_changeset(%__MODULE__{df_content: current_content} = data_structure, params) do
    data_structure
    |> cast(params, [:confidential, :df_content])
    |> update_change(:df_content, &Content.merge(&1, current_content))
    |> put_audit(params)
    |> validate_change(:df_content, Content.validator(data_structure))
  end

  defp put_audit(%{changes: changes} = changeset, _params)
       when map_size(changes) == 0 do
    changeset
  end

  defp put_audit(changeset, %{} = params) do
    cast(changeset, params, @audit_fields)
  end
end
