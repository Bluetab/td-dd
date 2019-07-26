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
    |> cast(attrs, [:version])
  end

  @doc false
  def changeset(%DataStructureVersion{} = data_structure_version, attrs) do
    data_structure_version
    |> cast(attrs, [
      :version,
      :data_structure_id
    ])
    |> validate_required([:version, :data_structure_id])
  end

  def search_fields(%DataStructureVersion{
        data_structure: structure,
        version: version
      }) do

    structure
    |> DataStructure.search_fields()
    |> Map.put(:version, version)
  end

  def index_name(_) do
    "data_structure"
  end
end
