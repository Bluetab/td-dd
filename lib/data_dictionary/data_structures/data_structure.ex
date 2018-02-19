defmodule DataDictionary.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias DataDictionary.DataStructures.DataStructure

  schema "data_structures" do
    field :description, :string
    field :group, :string
    field :last_change, :utc_datetime
    field :modifier, :integer
    field :name, :string
    field :system, :string

    timestamps()
  end

  @doc false
  def changeset(%DataStructure{} = data_structure, attrs) do
    data_structure
    |> cast(attrs, [:system, :group, :name, :description, :last_change, :modifier])
    |> validate_required([:system, :group, :name, :last_change, :modifier])
    |> validate_length(:system, max: 255)
    |> validate_length(:group, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:description,  max: 500)
  end
end
