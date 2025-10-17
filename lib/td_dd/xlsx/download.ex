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

  def write_notes_to_memory(%{main: main, children: children}, opts \\ []) do
    main_sheet = create_notes_sheet(main, "", opts)
    children_sheets = create_notes_sheet(children, "", opts)

    sheets = [main_sheet | children_sheets]
    workbook = %Workbook{sheets: sheets}
    Elixlsx.write_to_memory(workbook, "structure_notes.xlsx")
  end

  defp create_notes_sheet(data, prefix, opts) when is_list(data) do
    Enum.map(data, fn d ->
      create_notes_sheet(d, prefix, opts)
    end)
  end

  defp create_notes_sheet(%{structure: structure, notes: notes}, prefix, opts) do
    sheet_name =
      structure
      |> Map.get(:name, "")
      |> format_sheet_name(prefix)
      |> truncate_sheet_name()

    rows = Writer.structure_notes_rows(notes, structure, opts)
    %Sheet{name: sheet_name, rows: rows}
  end

  defp format_sheet_name(name, ""), do: name
  defp format_sheet_name(name, prefix), do: "#{prefix} - #{name}"

  defp truncate_sheet_name(name) when byte_size(name) > 31 do
    String.slice(name, 0, 31)
  end

  defp truncate_sheet_name(name), do: name

  defp sheets(rows_by_type) do
    Enum.map(rows_by_type, fn {type, rows} -> %Sheet{name: type, rows: rows} end)
  end
end
