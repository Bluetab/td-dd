defmodule TdDd.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Systems.System

  schema "data_structures" do
    belongs_to(:system, System, on_replace: :update)
    has_many(:versions, DataStructureVersion, on_delete: :delete_all)
    has_many(:structure_metadata_versions, StructureMetadata, on_delete: :delete_all)
    has_one(:profile, Profile, on_delete: :delete_all)

    field(:confidential, :boolean)
    field(:df_content, :map)
    field(:domain_id, :integer)
    field(:external_id, :string)
    field(:last_change_by, :integer)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :confidential,
      :df_content,
      :last_change_by
    ])
  end

  @doc false
  def changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :confidential,
      :df_content,
      :domain_id,
      :external_id,
      :last_change_by,
      :system_id
    ])
    |> validate_required([
      :last_change_by,
      :external_id,
      :system_id
    ])
  end
end
