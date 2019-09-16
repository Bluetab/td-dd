defmodule TdDd.DataStructures.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure


  schema "profiles" do
    field :value, :map
    belongs_to :data_structure, DataStructure

    timestamps()
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:value])
    |> validate_required([:value])
  end
end
