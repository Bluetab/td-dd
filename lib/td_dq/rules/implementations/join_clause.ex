defmodule TdDq.Rules.Implementations.JoinClause do
  @moduledoc """
  Ecto Schema module for Join clauses in rule implementations
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Rules.Implementations.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:right, Structure, on_replace: :delete)
    embeds_one(:left, Structure, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:left, with: &Structure.changeset/2, required: true)
    |> cast_embed(:right, with: &Structure.changeset/2, required: true)
  end
end
