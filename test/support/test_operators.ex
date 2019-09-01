defmodule TdDd.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion

  def a <~> b, do: approximately_equal(a, b)

  defp approximately_equal([_ | _] = l1, [_ | _] = l2) do
    l1 = Enum.sort(l1)
    l2 = Enum.sort(l2)
    approximately_equal_sorted(l1, l2)
  end

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%DataStructure{} = a, %DataStructure{} = b) do
    Map.drop(a, [:versions, :system]) ==
      Map.drop(b, [:versions, :system])
  end

  ## Equality test for data structure versions without comparing Ecto associations.
  defp approximately_equal(%DataStructureVersion{} = a, %DataStructureVersion{} = b) do
    Map.drop(a, [:children, :parents]) ==
      Map.drop(b, [:children, :parents])
  end

  defp approximately_equal(a, b), do: a == b

  defp approximately_equal_sorted([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end
end
