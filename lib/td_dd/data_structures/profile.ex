defmodule TdDd.DataStructures.Profile do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure

  schema "profiles" do
    field(:value, :map)
    belongs_to(:data_structure, DataStructure)

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(profile, params) do
    profile
    |> cast(params, [:value, :data_structure_id])
    |> validate_required([:value, :data_structure_id])
  end
end
