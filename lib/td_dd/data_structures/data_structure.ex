defmodule TdDd.DataStructures.DataStructure do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure

  @data_structure_modifiable_fields Application.get_env(:td_dd, :metadata)[:data_structure_modifiable_fields]

  schema "data_structures" do
    field :description, :string
    field :group, :string
    field :last_change_at, :utc_datetime
    field :last_change_by, :integer
    field :name, :string
    field :system, :string
    field :type, :string
    field :ou,   :string
    field :lopd, :string
    has_many :data_fields, DataField
    field :metadata, :map

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
    |> cast(attrs, [:system, :group, :name, :description, :last_change_at, :last_change_by, :type, :ou, :lopd, :metadata])
    |> validate_required([:system, :group, :name, :last_change_at, :last_change_by, :metadata])
    |> validate_length(:system, max: 255)
    |> validate_length(:group,  max: 255)
    |> validate_length(:name,   max: 255)
    |> validate_length(:type,   max: 255)
    |> validate_length(:ou,     max: 255)
    |> validate_length(:lopd,   max: 255)
  end
end
