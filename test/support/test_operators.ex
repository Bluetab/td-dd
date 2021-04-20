defmodule TdDd.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDq.Rules.Implementations.Implementation

  def a <~> b, do: approximately_equal(a, b)
  def a <|> b, do: approximately_equal(Enum.sort(a), Enum.sort(b))

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%DataStructure{} = a, %DataStructure{} = b) do
    Map.drop(a, [:versions, :system]) ==
      Map.drop(b, [:versions, :system])
  end

  ## Equality test for data structure versions without comparing Ecto associations.
  defp approximately_equal(%DataStructureVersion{} = a, %DataStructureVersion{} = b) do
    Map.drop(a, [:children, :parents, :data_structure, :external_id, :path]) ==
      Map.drop(b, [:children, :parents, :data_structure, :external_id, :path])
  end

  ## Equality test for rule implementation without comparing Ecto associations.
  defp approximately_equal(%Implementation{} = a, %Implementation{} = b) do
    Map.drop(a, [:rule]) == Map.drop(b, [:rule])
  end

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(a, b), do: a == b
end
