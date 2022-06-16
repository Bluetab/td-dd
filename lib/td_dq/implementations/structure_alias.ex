defmodule TdDq.Implementations.StructureAlias do
  @moduledoc """
  Ecto Schema module for Alias references in rule implementations datasets
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:index, :integer)
    field(:text, :string)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:index, :text])
    |> validate_required(:index)
  end
end
