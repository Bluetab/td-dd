defmodule TdDd.DataStructures.System do
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.System


  schema "systems" do
    field :external_ref, :string
    field :name, :string

    has_many :systems, System
    timestamps()
  end

  @doc false
  def changeset(system, attrs) do
    system
    |> cast(attrs, [:name, :external_ref])
    |> validate_required([:name, :external_ref])
  end
end
