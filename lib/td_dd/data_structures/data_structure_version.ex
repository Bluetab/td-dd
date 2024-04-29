defmodule TdDd.DataStructures.DataStructureVersion do
  @moduledoc """
  Ecto Schema module for Data Structure Versions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.Classification
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureType
  import Ecto.Query

  @typedoc "A data structure version"
  @type t :: %__MODULE__{}

  schema "data_structure_versions" do
    field(:version, :integer, default: 0)
    field(:class, :string)
    field(:description, :string)
    field(:metadata, :map, default: %{})
    field(:group, :string)
    field(:name, :string)
    field(:type, :string)
    field(:deleted_at, :utc_datetime_usec)
    field(:hash, :binary)
    field(:ghash, :binary)
    field(:lhash, :binary)
    field(:path, {:array, :map}, virtual: true, default: [])
    field(:external_id, :string, virtual: true)
    field(:profile_source, :map, virtual: true)
    field(:classes, :map, virtual: true)
    field(:mutable_metadata, :map, virtual: true)
    field(:note, :map, virtual: true)
    field(:grants, {:array, :map}, virtual: true)
    field(:grant, :map, virtual: true)
    field(:with_profiling, :boolean, virtual: true)
    field(:_filters, :map, virtual: true)
    field(:tag_names, {:array, :string}, virtual: true)
    field(:implementation_count, :integer, virtual: true)

    belongs_to(:data_structure, DataStructure)

    belongs_to(:structure_type, DataStructureType,
      foreign_key: :type,
      references: :name,
      define_field: false
    )

    has_many(:classifications, Classification)
    has_many(:child_relations, DataStructureRelation, foreign_key: :parent_id)
    has_many(:parent_relations, DataStructureRelation, foreign_key: :child_id)
    has_one(:current_metadata, through: [:data_structure, :current_metadata])
    has_one(:published_note, through: [:data_structure, :published_note])

    many_to_many(:children, __MODULE__,
      join_through: DataStructureRelation,
      join_keys: [parent_id: :id, child_id: :id]
    )

    many_to_many(:parents, __MODULE__,
      join_through: DataStructureRelation,
      join_keys: [child_id: :id, parent_id: :id]
    )

    timestamps(type: :utc_datetime_usec)
  end

  def update_changeset(%__MODULE__{} = data_structure_version, params) do
    data_structure_version
    |> cast(params, [
      :class,
      :deleted_at,
      :description,
      :hash,
      :lhash,
      :ghash,
      :metadata,
      :group,
      :name,
      :type,
      :version
    ])
    |> validate_lengths()
    |> preserve_timestamp_on_delete()
  end

  defp preserve_timestamp_on_delete(
         %{changes: %{deleted_at: deleted_at}, data: %{updated_at: updated_at}} = changeset
       )
       when not is_nil(deleted_at) do
    force_change(changeset, :updated_at, updated_at)
  end

  defp preserve_timestamp_on_delete(changeset), do: changeset

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = data_structure_version, params) do
    data_structure_version
    |> cast(params, [
      :class,
      :data_structure_id,
      :description,
      :group,
      :metadata,
      :name,
      :type,
      :version,
      :lhash,
      :ghash,
      :hash
    ])
    |> validate_required([:data_structure_id, :group, :metadata, :name, :version])
    |> validate_lengths()
  end

  defp validate_lengths(changeset) do
    changeset
    |> validate_length(:class, max: 255)
    |> validate_length(:group, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:type, max: 255)
  end

  def with_data_structure do
    from __MODULE__, preload: :data_structure
  end
end
