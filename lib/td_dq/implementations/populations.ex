defmodule TdDq.Implementations.Populations do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Implementations.ConditionRow

  @primary_key false
  embedded_schema do
    embeds_many(:population, ConditionRow, on_replace: :delete)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:population, with: &ConditionRow.changeset/2)
  end
end
