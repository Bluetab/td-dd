defmodule TdDd.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo
  alias TdDd.Searchable

  @behaviour Searchable

  @td_auth_api Application.get_env(:td_dd, :auth_service)[:api_service]
  @data_structure_modifiable_fields Application.get_env(:td_dd, :metadata)[
                                      :data_structure_modifiable_fields
                                    ]

  schema "data_structures" do
    field(:description, :string)
    field(:group, :string)
    field(:last_change_at, :utc_datetime)
    field(:last_change_by, :integer)
    field(:name, :string)
    field(:system, :string)
    field(:type, :string)
    field(:ou, :string)
    field(:lopd, :string)
    has_many(:data_fields, DataField)
    field(:metadata, :map)

    timestamps()
  end

  @doc false
  def update_changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [:last_change_at, :last_change_by] ++ @data_structure_modifiable_fields)
  end

  @doc false
  def changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [
      :system,
      :group,
      :name,
      :description,
      :last_change_at,
      :last_change_by,
      :type,
      :ou,
      :lopd,
      :metadata
    ])
    |> validate_required([:system, :group, :name, :last_change_at, :last_change_by, :metadata])
    |> validate_length(:system, max: 255)
    |> validate_length(:group, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:type, max: 255)
    |> validate_length(:ou, max: 255)
    |> validate_length(:lopd, max: 255)
  end

  def search_fields(%DataStructure{last_change_by: last_change_by_id, metadata: metadata} = structure) do
    last_change_by = case @td_auth_api.get_user(last_change_by_id) do
      nil -> %{}
      user -> user |> Map.take([:id, :user_name, :full_name])
    end

    metadata = %{}

    %{
      id: structure.id,
      description: structure.description,
      group: structure.group,
      last_change_at: structure.last_change_at,
      last_change_by: last_change_by,
      lopd: structure.lopd,
      name: structure.name,
      ou: structure.ou,
      system: structure.system,
      type: structure.type,
      inserted_at: structure.inserted_at,
      data_fields: Enum.map(Repo.preload(structure, :data_fields).data_fields, &search_fields(&1)),
      metadata: metadata
    }
  end

  def search_fields(%DataField{last_change_by: last_change_by_id, metadata: metadata} = field) do
    last_change_by = case @td_auth_api.get_user(last_change_by_id) do
      nil -> %{}
      user -> user |> Map.take([:id, :user_name, :full_name])
    end

    metadata = %{}
    %{
      id: field.id,
      business_concept_id: field.business_concept_id,
      data_structure_id: field.data_structure_id,
      description: field.description,
      external_id: field.external_id,
      inserted_at: field.inserted_at,
      last_change_at: field.last_change_at,
      last_change_by: last_change_by,
      metadata: metadata,
      name: field.name,
      nullable: field.nullable,
      precision: field.precision,
      type: field.type,
      updated_at: field.updated_at
    }
  end

  def index_name do
    "data_structure"
  end
end
