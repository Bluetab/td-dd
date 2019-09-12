defmodule TdDd.DataStructures.DataStructureVersion do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Searchable

  @behaviour Searchable

  schema "data_structure_versions" do
    field(:version, :integer, default: 0)
    field(:class, :string)
    field(:description, :string)
    field(:metadata, :map, default: %{})
    field(:group, :string)
    field(:name, :string)
    field(:type, :string)
    field(:deleted_at, :utc_datetime)
    field(:hash, :binary)
    field(:ghash, :binary)
    field(:lhash, :binary)

    belongs_to(:data_structure, DataStructure)

    many_to_many(:children, DataStructureVersion,
      join_through: DataStructureRelation,
      join_keys: [parent_id: :id, child_id: :id]
    )

    many_to_many(:parents, DataStructureVersion,
      join_through: DataStructureRelation,
      join_keys: [child_id: :id, parent_id: :id]
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%DataStructureVersion{} = data_structure_version, attrs) do
    data_structure_version
    |> cast(attrs, [
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
    changeset
    |> force_change(:updated_at, updated_at)
  end

  defp preserve_timestamp_on_delete(changeset), do: changeset

  @doc false
  def changeset(%DataStructureVersion{} = data_structure_version, attrs) do
    data_structure_version
    |> cast(attrs, [
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

  def search_fields(%DataStructureVersion{data_structure: structure, version: version}) do
    structure
    |> DataStructure.search_fields()
    |> Map.put(:version, version)
  end

  def index_name(_) do
    "data_structure"
  end
end
