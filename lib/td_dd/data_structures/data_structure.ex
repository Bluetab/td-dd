defmodule TdDd.DataStructures.DataStructure do
  @moduledoc """
  Ecto Schema module for Data Structures.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCx.Sources.Source
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Grants.Grant
  alias TdDd.Lineage.Units.Node
  alias TdDd.Profiles.Profile
  alias TdDd.Systems.System
  alias TdDq.Implementations.ImplementationStructure

  @typedoc "A data structure"
  @type t :: %__MODULE__{}

  schema "data_structures" do
    field(:confidential, :boolean)
    field(:domain_ids, {:array, :integer}, default: [])
    field(:external_id, :string)
    field(:last_change_by, :integer)
    field(:row, :integer, virtual: true)
    field(:latest_metadata, :map, virtual: true)
    field(:domains, :map, virtual: true)
    field(:linked_concepts, :boolean, virtual: true)
    field(:latest_note, :map, virtual: true)
    field(:search_content, :map, virtual: true)
    field(:alias, :string)

    has_one(:published_note, StructureNote, where: [status: :published])

    belongs_to(:system, System, on_replace: :update)
    belongs_to(:source, Source)

    has_many(:versions, DataStructureVersion)
    has_many(:metadata_versions, StructureMetadata)
    has_many(:note_versions, StructureNote)
    has_one(:profile, Profile)
    has_many(:structure_tags, StructureTag)
    has_many(:grants, Grant)
    many_to_many(:tags, Tag, join_through: StructureTag)
    has_one(:current_version, DataStructureVersion, where: [deleted_at: nil])
    has_one(:current_metadata, StructureMetadata, where: [deleted_at: nil])
    has_many(:implementations, ImplementationStructure, where: [deleted_at: nil])
    has_many(:nodes, Node, foreign_key: :structure_id)
    has_many(:units, through: [:nodes, :units])

    many_to_many(:linked_data_structures, __MODULE__,
      join_through: DataStructureLink,
      join_keys: [source_id: :id, target_id: :id]
    )

    has_many(:data_structure_links, DataStructureLink, foreign_key: :source_id)

    timestamps(type: :utc_datetime_usec)
  end

  def alias_changeset(%__MODULE__{} = data_structure, value, last_change_by) do
    data_structure
    |> cast(%{alias: value}, [:alias])
    |> put_audit(last_change_by)
  end

  def changeset(%__MODULE__{} = data_structure, params, last_change_by)
      when is_integer(last_change_by) do
    data_structure
    |> cast(params, [:confidential, :domain_ids])
    |> validate_change(:domain_ids, fn
      _, [_ | _] -> []
      _, _ -> [domain_ids: "must be a non-empty list"]
    end)
    |> unique_domain_ids()
    |> put_audit(last_change_by)
  end

  defp put_audit(%{changes: changes} = changeset, _last_change_by)
       when map_size(changes) == 0 do
    changeset
  end

  defp put_audit(changeset, last_change_by) do
    force_change(changeset, :last_change_by, last_change_by)
  end

  defp unique_domain_ids(changeset) do
    update_change(changeset, :domain_ids, fn domain_ids ->
      domain_ids
      |> Enum.sort()
      |> Enum.uniq()
    end)
  end
end
