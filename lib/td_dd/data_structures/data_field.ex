defmodule TdDd.DataStructures.DataField do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataField

  schema "data_fields" do
    field :business_concept_id, :string, default: nil
    field :description, :string, default: nil
    field :last_change_at, :utc_datetime
    field :last_change_by, :integer
    field :name, :string
    field :nullable, :boolean, default: nil
    field :precision, :integer, default: nil
    field :type, :string, default: nil
    field :data_structure_id, :id

    timestamps()
  end

  @doc false
  def changeset(%DataField{} = data_field, attrs) do
    data_field
    |> cast(attrs, [:name, :type, :precision, :nullable, :description, :business_concept_id, :data_structure_id, :last_change_at, :last_change_by])
    |> validate_required([:name, :type, :precision, :nullable, :data_structure_id, :last_change_at, :last_change_by])
    |> validate_length(:name, max: 255)
    |> validate_length(:description,  max: 500)
    |> validate_length(:business_concept_id, max: 255)
    |> foreign_key_constraint(:data_structure_id)
  end
end
