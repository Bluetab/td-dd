defmodule Timer do
  @moduledoc """
  Utility for timing function invocations
  """

  def time(fun, unit \\ :millis)

  def time(fun, :millis), do: do_time(fun, 1_000)

  def time(fun, :seconds), do: do_time(fun, 1_000_000)

  defp do_time(fun, divisor) do
    {micros, res} = :timer.tc(fun)
    {div(micros, divisor), res}
  end
end
