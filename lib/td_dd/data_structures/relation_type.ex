defmodule TdDd.DataStructures.RelationType do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDd.DataStructures.RelationType

  @default "default"

  schema "relation_types" do
    field(:name, :string)
    field(:description, :string)

    timestamps()
  end

  @doc false
  def changeset(%RelationType{} = relation_type, attrs) do
    relation_type
    |> cast(attrs, [
      :name,
      :description
    ])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def default do
    @default
  end
end
