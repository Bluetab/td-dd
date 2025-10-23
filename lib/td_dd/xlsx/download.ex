defmodule TdDd.XLSX.Download do
  @moduledoc """
  Helper module to download xlsx files for:
  - structures published and pending (non-published) notes.
  - grants
  """
  alias Elixlsx.Sheet
  alias Elixlsx.Workbook
  alias TdDd.XLSX.Writer

  def write_to_memory(structures, structure_url_schema, opts \\ []) do
    structures
    |> Writer.data_structure_type_information(opts)
    |> Writer.rows_by_structure_type(structure_url_schema, opts)
    |> sheets()
    |> then(fn [_ | _] = sheets ->
      workbook = %Workbook{sheets: sheets}
      Elixlsx.write_to_memory(workbook, "structures.xlsx")
    end)
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
    Enum.map(rows_by_type, fn {type, rows} -> %Sheet{name: type, rows: rows} end)
  end
end
