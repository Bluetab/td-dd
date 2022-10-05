defmodule TdDq.Functions.Argument do
  @moduledoc """
  Ecto Schema module for functions arguments in data quality implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :type, :string
    field :name, :string
    field :values, {:array, :string}
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:type, :name, :values])
    |> validate_required([:type])
  end
end
