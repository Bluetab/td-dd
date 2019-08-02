defmodule TdDd.Systems.System do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Searchable
  alias TdDd.Systems.System

  @behaviour Searchable

  schema "systems" do
    field(:external_id, :string)
    field(:name, :string)

    has_many(:data_structures, DataStructure)
    timestamps()
  end

  @doc false
  def changeset(system, attrs) do
    system
    |> cast(attrs, [:name, :external_id])
    |> validate_required([:name, :external_id])
  end

  def search_fields(%System{} = system) do
    system
    |> Map.take([:id, :external_id, :name])
  end

  def index_name(_) do
    "system"
  end
end
