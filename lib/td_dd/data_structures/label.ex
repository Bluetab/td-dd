defmodule TdDd.DataStructures.Label do
  @moduledoc """
  Ecto Schema module for DataStructureLink Labels
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureLinkLabel

  schema "labels" do
    field(:name, :string)

    many_to_many(:data_structure_links, DataStructureLink,
      join_through: DataStructureLinkLabel,
      on_delete: :delete_all
    )

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = label, %{} = params) do
    label
    |> cast(params, [:name])
    |> validate_required(:name)
    |> unique_constraint(:name)
  end
end
