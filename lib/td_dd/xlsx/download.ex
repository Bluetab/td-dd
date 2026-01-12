defmodule TdDd.XLSX.Download do
  @moduledoc """
  Helper module to download xlsx files for:
  - structures published and pending (non-published) notes.
  - grants
  """
  alias Elixlsx.Sheet
  alias Elixlsx.Workbook
  alias TdDd.XLSX.Writer

  require Logger

  def write_to_memory(structures, structure_url_schema, opts \\ []) do
    Logger.info("Start writing to memory")

    result =
      structures
      |> Writer.data_structure_type_information(opts)
      |> Writer.rows_by_structure_type(structure_url_schema, opts)
      |> sheets()
      |> then(fn [_ | _] = sheets ->
        workbook = %Workbook{sheets: sheets}
        Elixlsx.write_to_memory(workbook, "structures.xlsx")
      end)

    Logger.info("End writing to memory")
    result
  end

  def write_to_memory_grants(grants, header_labels \\ nil) do
    grants
    |> Writer.grant_rows(header_labels)
    |> then(fn rows ->
      sheet = %Sheet{name: "Grants", rows: rows}
      workbook = %Workbook{sheets: [sheet]}
      Elixlsx.write_to_memory(workbook, "grants.xlsx")
    end)
  end

  defp sheets(rows_by_type) do
    Enum.map(rows_by_type, fn {type, rows} ->
      name = sanitize_sheet_name(type)
      %Sheet{name: name, rows: rows}
    end)
  end

  defp sanitize_sheet_name(name) when is_binary(name) do
    name
    # Reemplazar caracteres no permitidos
    |> String.replace(~r/[[\]:*?\/\\]/, "_")
    # Limitar a 31 caracteres
    |> String.slice(0, 31)
    |> then(fn
      # Si queda vacío, usar un nombre por defecto
      "" -> "Sheet"
      name -> name
    end)
  end

  defp sanitize_sheet_name(_), do: "Sheet"
end
