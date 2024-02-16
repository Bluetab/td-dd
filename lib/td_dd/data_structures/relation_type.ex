defmodule TdDd.DataStructures.RelationType do
  @moduledoc """
  Ecto Schema module for relation types (types of relationships between data
  structures).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.DataStructures.RelationType

  schema "relation_types" do
    field(:name, :string)
    field(:description, :string)

    timestamps()
  end

  def changeset(%RelationType{} = relation_type, params) do
    relation_type
    |> cast(params, [:name, :description])
    |> validate_required(:name)
    |> unique_constraint(:name)
  end
end
