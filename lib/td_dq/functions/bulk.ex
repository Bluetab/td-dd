defmodule TdDq.Functions.Bulk do
  @moduledoc """
  Ecto embedded schema for validating input when bulk loading functions
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Functions.Function

  @primary_key false

  embedded_schema do
    embeds_many :functions, Function
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:functions, with: &Function.changeset/2, required: true)
  end
end
