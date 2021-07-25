defmodule TdDd.DataStructures.DataStructure do
  @moduledoc """
  Ecto Schema module for Data Structures.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Sources.Source
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Grants.Grant
  alias TdDd.Systems.System

  @audit_fields [:last_change_by]

  @typedoc "A data structure"
  @type t :: %__MODULE__{}

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    belongs_to(:source, Source)

    has_many(:versions, DataStructureVersion)
    has_many(:metadata_versions, StructureMetadata)
    has_many(:note_versions, StructureNote)
    has_one(:profile, Profile)
    has_many(:data_structures_tags, DataStructuresTags)
    has_many(:grants, Grant)
    many_to_many(:tags, DataStructureTag, join_through: DataStructuresTags)

    field(:confidential, :boolean)
    field(:domain_id, :integer)
    field(:external_id, :string)
    field(:last_change_by, :integer)
    field(:row, :integer, virtual: true)
    field(:latest_metadata, :map, virtual: true)
    field(:latest_note, :map, virtual: true)
    field(:domain, :map, virtual: true)
    field(:domain_parents, {:array, :map}, virtual: true)
    # Note, the value of this field is 1 (has linked concepts) or 0 (no linked concepts)
    field(:linked_concepts_count, :integer, virtual: true)
    field(:search_content, :map, virtual: true)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [
      :confidential,
      :domain_id,
      :external_id,
      :source_id,
      :system_id
    ])
    |> put_audit(params)
    |> validate_required([
      :external_id,
      :last_change_by,
      :system_id
    ])
  end

  def update_changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [:confidential, :domain_id])
    |> put_audit(params)
  end

  def merge_changeset(%__MODULE__{} = data_structure, params) do
    data_structure
    |> cast(params, [:confidential])
    |> put_audit(params)
  end

  defp put_audit(%{changes: changes} = changeset, _params)
       when map_size(changes) == 0 do
    changeset
  end

  defp put_audit(changeset, %{} = params) do
    cast(changeset, params, @audit_fields)
  end
end
