defmodule TdDd.DataStructures.System do
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure


  schema "systems" do
    field :external_ref, :string
    field :name, :string

    has_many :data_structures, DataStructure
    timestamps()
  end

  @doc false
  def changeset(system, attrs) do
    system
    |> cast(attrs, [:name, :external_ref])
    |> validate_required([:name, :external_ref])
  end
end
