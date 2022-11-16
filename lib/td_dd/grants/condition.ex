defmodule TdDd.Grants.Condition do
  @moduledoc """
  Ecto Schema module for Grant Request Condition
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :field, :string
    field :operator, :string
    field :value, :string
  end

  def changeset(%{} = attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  def changeset(%__MODULE__{} = struct, %{} = attrs) do
    struct
    |> cast(attrs, [:field, :operator, :value])
    |> validate_required([
      :field,
      :operator,
      :value
    ])
  end
end
