defmodule TdDq.Implementations.SegmentsRow do
  @moduledoc """
  Ecto Schema module for segments in rule implementation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Implementations.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:structure, Structure, on_replace: :delete)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [])
    |> cast_embed(:structure, with: &Structure.changeset/2, required: true)
  end
end
