defmodule TdDd.DataStructures.Paths.Path do
  @moduledoc """
  Ecto Schema module for data structure paths
  """

  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:id, :integer)
    field(:vid, :integer)
    field(:name, :string)
    field(:v_sum, :integer)
    field(:names, {:array, :string})
    field(:structure_ids, {:array, :integer})
    field(:external_ids, {:array, :string})
  end
end
