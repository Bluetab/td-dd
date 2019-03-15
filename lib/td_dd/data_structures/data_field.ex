defmodule TdDd.DataStructures.DataField do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructureVersion

  @data_field_modifiable_fields Application.get_env(:td_dd, :metadata)[
                                  :data_field_modifiable_fields
                                ]
                                |> Enum.map(&String.to_atom/1)

  schema "data_fields" do
    field(:business_concept_id, :string, default: nil)
    field(:description, :string, default: nil)
    field(:last_change_at, :utc_datetime)
    field(:last_change_by, :integer)
    field(:name, :string)
    field(:nullable, :boolean, default: nil)
    field(:precision, :string, default: nil)
    field(:type, :string, default: nil)
    field(:metadata, :map, default: %{})

    many_to_many(:data_structure_versions, DataStructureVersion,
      join_through: "versions_fields",
      on_delete: :delete_all
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def update_changeset(%DataField{} = data_field, attrs) do
    data_field
    |> cast(attrs, [:last_change_at, :last_change_by] ++ @data_field_modifiable_fields)
  end

  @doc false
  def loader_changeset(%DataField{} = data_field, attrs) do
    changeset = data_field |> cast(attrs, @data_field_modifiable_fields)

    case changeset.changes do
      %{} -> changeset
      _ -> update_changeset(data_field, attrs)
    end
  end

  @doc false
  def changeset(%DataField{} = data_field, attrs) do
    data_field
    |> cast(attrs, [
      :name,
      :type,
      :precision,
      :nullable,
      :description,
      :business_concept_id,
      :last_change_at,
      :last_change_by,
      :metadata
    ])
    |> validate_required([:name, :last_change_at, :last_change_by, :metadata])
    |> validate_length(:name, max: 255)
    |> validate_length(:business_concept_id, max: 255)
  end

  def search_fields(field) do
    %{
      id: field.id,
      business_concept_id: field.business_concept_id,
      description: field.description,
      inserted_at: field.inserted_at,
      last_change_at: field.last_change_at,
      name: field.name,
      nullable: field.nullable,
      precision: field.precision,
      type: field.type,
      updated_at: field.updated_at
    }
  end
end
