defmodule TdDd.Systems.System do
  @moduledoc """
  Ecto schema module for Systems.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructure

  schema "systems" do
    field(:external_id, :string)
    field(:name, :string)
    field(:df_content, :map)

    has_many(:data_structures, DataStructure)
    timestamps()
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = system, params) do
    system
    |> cast(params, [:name, :external_id, :df_content])
    |> validate_required([:name, :external_id])
    |> unique_constraint(:external_id)
  end
end
