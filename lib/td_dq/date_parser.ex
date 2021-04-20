defmodule TdDq.DateParser do
  @moduledoc """
  A datetime parser supporting multiple formats.
  """

  @formats [:iso, :utc, :utc_date, :legacy]
  @legacy_format ~r/^(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})$/

  @doc """
  Parses a value using any of the following formats:
    * :iso - An ISO8601 formatted datetime
    * :utc - An ISO8601 datetime without the timezone specified
    * :utc_date - A date formatted as YYYY-MM-DD
    * :legacy - A legacy formatted date YYYY-MM-DD-HH-MM-SS

  A successful result will return {:ok, datetime, offset} (See DateTime.from_iso8601/1).
  A failure will return {:error, reason}.

    ## Examples

      iex> {:ok, datetime, 7200} = TdDq.DateParser.parse("2015-01-24T01:50:07+02:00")
      iex> datetime
      ~U[2015-01-23 23:50:07Z]

      iex> {:ok, datetime, _} = TdDq.DateParser.parse("2015-01-23")
      iex> datetime
      ~U[2015-01-23 00:00:00Z]

      iex> TdDq.DateParser.parse("2015-02-29")
      {:error, :invalid_date}

  """
  def parse(str, formats \\ @formats) do
    Enum.reduce_while(formats, {:error, :invalid_format}, fn format, _acc ->
      case do_parse(str, format) do
        {:ok, datetime, offset} -> {:halt, {:ok, datetime, offset}}
        {:error, :invalid_date} -> {:halt, {:error, :invalid_date}}
        {:error, :invalid_time} -> {:halt, {:error, :invalid_time}}
        e -> {:cont, e}
      end
    end)
  end

  defp do_parse(str, :iso), do: DateTime.from_iso8601(str)

  defp do_parse(str, :utc), do: DateTime.from_iso8601(str <> "Z")

  defp do_parse(str, :utc_date), do: DateTime.from_iso8601(str <> "T00:00:00Z")

  defp do_parse(str, :legacy) do
    case Regex.run(@legacy_format, str, capture: :all_but_first) do
      [year, month, day, hour, minute, second] ->
        DateTime.from_iso8601("#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}Z")

      _ ->
        {:error, :invalid_format}
    end
  end
end
