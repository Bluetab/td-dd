defmodule TdDq.CSV.Reader do
  @moduledoc """
  Module to read CSV
  """

  alias Codepagex
  alias NimbleCSV

  NimbleCSV.define(ReaderCsvParser, separator: ";", escape: "\"")

  @csv_parse_chunk_size 10_000

  def parse_csv(stream, required_headers) do
    with {:ok, csv} <- parse_stream(stream),
         headers <- Enum.at(csv, 0),
         {:ok, headers} <- validate_headers(required_headers, headers) do
      parse_file(csv, headers)
    end
  end

  defp parse_stream(stream) do
    {:ok, ReaderCsvParser.parse_stream(stream, skip_headers: false)}
  end

  defp validate_headers(required_headers, headers) do
    if Enum.all?(required_headers, &Enum.member?(headers, &1)) do
      {:ok, headers}
    else
      {:error,
       %{
         error: :missing_required_columns,
         expected: Enum.join(required_headers, ", "),
         found: Enum.join(headers, ", ")
       }}
    end
  end

  defp parse_file(csv, headers) do
    parsed_file =
      csv
      |> Stream.drop(1)
      |> Stream.chunk_every(@csv_parse_chunk_size)
      |> Enum.flat_map(&parse(&1, headers))

    {:ok, parsed_file}
  end

  defp parse(chunk, headers) do
    Enum.map(chunk, fn fields ->
      # TODO: Can this "decoding" be done elsewhere? Some ideas:
      # - While streaming the file?
      # - Using the CSV library?
      fields = Enum.map(fields, &decode_row/1)

      headers
      |> Enum.zip(fields)
      |> Map.new()
    end)
  end

  defp decode_row(row) do
    if String.valid?(row) do
      row
    else
      Codepagex.to_string!(row, "VENDORS/MICSFT/WINDOWS/CP1252", Codepagex.use_utf_replacement())
    end
  end
end
