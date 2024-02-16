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
    # TD-5391 value is deprecated - use values instead
    field :value, :string
    field :values, {:array, :string}
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:field, :operator, :values])
    |> validate_required([:field, :operator, :values])
  end
end
