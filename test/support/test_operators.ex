defmodule TdDq.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdDq.Rules.Implementations.Implementation

  def a <~> b, do: approximately_equal(a, b)
  def a <|> b, do: approximately_equal(Enum.sort(a), Enum.sort(b))

  ## Equality test for rule implementation without comparing Ecto associations.
  defp approximately_equal(%Implementation{} = a, %Implementation{} = b) do
    Map.drop(a, [:rule]) == Map.drop(b, [:rule])
  end

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(a, b), do: a == b
end
