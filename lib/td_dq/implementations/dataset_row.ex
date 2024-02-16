defmodule TdDq.Implementations.DatasetRow do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDq.Implementations.JoinClause
  alias TdDq.Implementations.Structure
  alias TdDq.Implementations.StructureAlias

  @primary_key false
  embedded_schema do
    embeds_one(:alias, StructureAlias, on_replace: :delete)
    embeds_one(:structure, Structure, on_replace: :delete)
    embeds_many(:clauses, JoinClause, on_replace: :delete)
    field(:join_type, Ecto.Enum, values: [:inner, :right, :left, :full_outer])
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    clauses_required = get_validate_required(params)

    struct
    |> cast(params, [:join_type])
    |> cast_embed(:alias, with: &StructureAlias.changeset/2)
    |> cast_embed(:structure, with: &Structure.changeset/2, required: true)
    |> cast_embed(:clauses, with: &JoinClause.changeset/2, required: clauses_required)
  end

  defp get_validate_required(params) do
    case Map.get(params, :join_type, Map.get(params, "join_type")) do
      nil -> false
      _join_type -> true
    end
  end
end
