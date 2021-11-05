defmodule TdDq.Implementations.Modifier do
  @moduledoc """
  Ecto Schema module for Operators in rule implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:params, :map)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:name, :params])
    |> validate_required([:name])
  end
end
