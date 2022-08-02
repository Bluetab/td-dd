defmodule TdDq.CSV.Reader do
  @moduledoc """
  Module to read CSV
  """

  alias Codepagex
  alias NimbleCSV
  alias TdDq.Auth.Claims

  NimbleCSV.define(ReaderCsvParser, separator: ";", escape: "\"")

  @csv_parse_chunk_size 10_000

  @spec read_csv(Claims.t(), Enumerable.t(), [binary], function) :: {:ok, map} | {:error, any}
  def read_csv(claims, stream, required_headers, bulk_create) do
    with {:ok, csv} <- parse_stream(stream),
         headers <- Enum.at(csv, 0),
         {:ok, headers} <- validate_headers(required_headers, headers),
         {:ok, parsed_file} <- parse_file(csv, headers) do
      bulk_create.(parsed_file, claims)
    end
  end

  defp parse_stream(stream) do
    {:ok, ReaderCsvParser.parse_stream(stream, skip_headers: false)}
  end

  defp validate_headers(required_headers, headers) do
    if Enum.all?(required_headers, &Enum.member?(headers, &1)) do
      {:ok, headers}
    else
      {:error, %{error: :misssing_required_columns, expected: required_headers, found: headers}}
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
