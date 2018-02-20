defmodule DataDictionary.DataStructures.DataField do
  use Ecto.Schema
  import Ecto.Changeset
  alias DataDictionary.DataStructures.DataField


  schema "data_fields" do
    field :business_concept_id, :id
    field :description, :string
    field :last_change, :utc_datetime
    field :modifier, :integer
    field :name, :string
    field :nullable, :boolean, default: true
    field :precission, :integer, default: 0
    field :type, :string
    field :data_structure_id, :id

    timestamps()
  end

  @doc false
  def changeset(%DataField{} = data_field, attrs) do
    data_field
    |> cast(attrs, [:name, :type, :precission, :nullable, :description, :business_concept_id, :last_change, :modifier])
    |> validate_required([:name, :type, :precission, :nullable, :business_concept_id, :last_change, :modifier])
    |> validate_length(:name, max: 255)
    |> validate_length(:description,  max: 500)
  end
end
