defmodule TdDd.Util.Ensures do
  @moduledoc """
  Utility for ensuring types
  """

  def number(value) when is_number(value), do: value
  def number(value) when is_binary(value), do: String.to_integer(value)

  def list(value) when is_list(value), do: value
  def list(value), do: [value]

  def tuple(value) when is_tuple(value), do: value
  def tuple(value), do: {value, 0}

  def map(value) when is_map(value), do: value
  def map(value), do: %{value: value}

  def string(value) when is_binary(value), do: value
  def string(value), do: "#{value}"
end
