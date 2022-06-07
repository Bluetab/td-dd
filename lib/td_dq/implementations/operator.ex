defmodule TdDq.Implementations.Operator do
  @moduledoc """
  Ecto Schema module for Operators in rule implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:value_type, :string)
    field(:value_type_filter, :string)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :value_type, :value_type_filter])
    |> validate_required(:name)
  end
end
