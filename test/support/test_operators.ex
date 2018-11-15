defmodule TdDd.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdDd.DataStructures.DataStructure

  def a <~> b, do: approximately_equal(a, b)

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%DataStructure{} = a, %DataStructure{} = b) do
    Map.drop(a, [:versions, :data_fields]) == Map.drop(b, [:versions, :data_fields])
  end

  defp approximately_equal(a, b), do: a == b
end
