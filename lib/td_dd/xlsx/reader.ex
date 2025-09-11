defmodule TdDd.XLSX.Reader do
  @moduledoc """
  A module responsible for reading and parsing XLSX files.

  This module provides functionality to extract data from XLSX spreadsheets using
  the `XlsxReader` library and process it into a structured format for bulk updates.

  ## Functionality
  - Reads an XLSX file and extracts data from its sheets.
  - Transforms the data into a format suitable for processing.
  - Integrates with `TdDd.DataStructures.BulkUpdate` to facilitate bulk updates.

  ## Functions

  - `parse/2` - Reads and processes an XLSX file, returning parsed data.
  """
  alias TdDd.DataStructures.BulkUpdate

  @data_structure_preloads [:system, current_version: :structure_type]

  def parse(path, opts \\ []) do
    path
    |> read()
    |> do_parse(opts)
  end

  defp read(path) do
    with {:ok, package} <- XlsxReader.open(path),
         [_ | _] = sheet_names <- XlsxReader.sheet_names(package) do
      Enum.reduce(sheet_names, [], fn sheet, acc ->
        [{sheet, rows_for_sheet(package, sheet)} | acc]
      end)
    end
  end

  defp do_parse(rows_by_sheet, opts) do
    Enum.reduce_while(rows_by_sheet, {[], []}, fn {sheet, rows}, {acc_contents, acc_errors} ->
      opts = Keyword.merge([preload: @data_structure_preloads, sheet: sheet], opts)

      case BulkUpdate.parse(rows, opts) do
        {contents, external_id_errors} when is_list(contents) and is_list(external_id_errors) ->
          {:cont, {acc_contents ++ contents, acc_errors ++ external_id_errors}}

        {:error, _error} = error ->
          {:halt, error}
      end
    end)
  end

  defp rows_for_sheet(package, sheet) do
    {:ok, [headers | content]} = XlsxReader.sheet(package, sheet, number_type: String)
    Enum.map(content, fn row -> create_row(headers, row) end)
  end

  defp create_row(headers, row) do
    # issue in: https://github.com/xavier/xlsx_reader/issues/37
    # remove asap
    fill_tail = List.duplicate("", max(0, length(headers) - length(row)))

    headers
    |> Enum.zip(row ++ fill_tail)
    |> Map.new()
  end
end
