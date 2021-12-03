defmodule TdDq.CSV.Reader do
  @moduledoc """
  Module ro read Implementations CSV
  """
  alias TdDq.Implementations.BulkLoad

  ## TODO: debe de poder manejar distintos separadores ";", ","
  NimbleCSV.define(MyCsvParser, separator: ";", escape: "\"")

  @csv_parse_chunk_size 10_000

  @spec read_csv(binary, keyword) :: {:ok, [integer]} | {:error, any}
  def read_csv(stream, opts \\ []) do
    bulk_create = Keyword.get(opts, :bulk_load, &BulkLoad.bulk_load/1)

    stream
    |> decode!()
    |> bulk_create.()
  end

  defp decode!(stream) do
    csv = MyCsvParser.parse_stream(stream, skip_headers: false)
    headers = Enum.at(csv, 0)

    csv
    |> Stream.drop(1)
    |> Stream.chunk_every(@csv_parse_chunk_size)
    |> Enum.flat_map(&parse(&1, headers))
  end

  defp parse(chunk, headers) do
    Enum.map(chunk, fn fields ->
      headers
      |> Enum.zip(fields)
      |> Map.new()
    end)
  end
end
