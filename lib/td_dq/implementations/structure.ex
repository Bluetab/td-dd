defmodule TdDq.Implementations.Structure do
  @moduledoc """
  Ecto Schema module for DataStructure references in rule implementations
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :integer)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:id])
    |> validate_required([:id])
  end
end
