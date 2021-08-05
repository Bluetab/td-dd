defmodule TdDd.Profiles.Count do
  @moduledoc """
  Custom `Ecto.Type` to represent a non-negative count.
  """
  use Ecto.Type

  def type, do: :integer

  def cast(value) when is_integer(value) and value >= 0, do: {:ok, value}

  def cast(value) when is_binary(value) do
    value
    |> parse_int!()
    |> cast()
  rescue
    _ -> :error
  end

  def cast(_), do: :error

  def load(value) when is_integer(value) and value >= 0 do
    {:ok, value}
  end

  def load(_), do: :error

  def dump(value) when is_integer(value) and value >= 0, do: {:ok, value}
  def dump(_), do: :error

  defp parse_int!(value) do
    value
    |> Decimal.new()
    |> Decimal.to_integer()
  end
end
