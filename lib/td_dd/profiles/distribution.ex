defmodule TdDd.Profiles.Distribution do
  @moduledoc """
  Custom `Ecto.Type` to represent a frequency distribution.
  """

  use Ecto.Type

  def type, do: {:array, :map}

  def cast(values) when is_list(values) do
    values
    |> Enum.reverse()
    |> Enum.reduce_while([], fn i, acc ->
      case item(i) do
        {:ok, value} -> {:cont, [value | acc]}
        _ -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      items -> {:ok, items}
    end
  end

  def cast(maybe_json) when is_binary(maybe_json) do
    case Jason.decode(maybe_json) do
      {:ok, json} -> cast(json)
      _ -> :error
    end
  end

  def cast(_), do: :error

  def load(data) when is_list(data) do
    if Enum.all?(data, &valid_item?/1) do
      {:ok, data}
    else
      :error
    end
  end

  def dump(value) when is_list(value), do: {:ok, value}
  def dump(_), do: :error

  defp item([key, value]) when is_integer(value) do
    {:ok, %{"k" => key, "v" => value}}
  end

  defp item([key, value]) when is_binary(value) do
    item([key, parse_int!(value)])
  rescue
    _ -> :error
  end

  defp item(_), do: :error

  defp parse_int!(value) do
    value
    |> Decimal.new()
    |> Decimal.to_integer()
  end

  defp valid_item?(%{"k" => _, "v" => _}), do: true
  defp valid_item?(_), do: false
end
