defmodule TdDd.DataStructures.DataField do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure

  @data_field_modifiable_fields Application.get_env(:td_dd, :metadata)[
                                  :data_field_modifiable_fields
                                ]

  schema "data_fields" do
    field(:business_concept_id, :string, default: nil)
    field(:description, :string, default: nil)
    field(:last_change_at, :utc_datetime)
    field(:last_change_by, :integer)
    field(:name, :string)
    field(:nullable, :boolean, default: nil)
    field(:precision, :string, default: nil)
    field(:type, :string, default: nil)
    belongs_to(:data_structure, DataStructure)
    field(:metadata, :map)
    field(:external_id, :string, default: nil)

    timestamps()
  end

  @doc false
  def update_changeset(%DataField{} = data_field, attrs) do
    data_field
    |> cast(attrs, [:last_change_at, :last_change_by] ++ @data_field_modifiable_fields)
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
      :data_structure_id,
      :last_change_at,
      :last_change_by,
      :metadata,
      :external_id
    ])
    |> validate_required([:name, :data_structure_id, :last_change_at, :last_change_by, :metadata])
    |> validate_length(:name, max: 255)
    |> validate_length(:business_concept_id, max: 255)
    |> foreign_key_constraint(:data_structure_id)
  end
end
