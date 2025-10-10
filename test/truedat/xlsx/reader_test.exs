defmodule Truedat.XLSX.ReaderTest do
  @moduledoc """
  Tests for the XLSX Reader module.
  """
  use TdDd.DataCase

  alias Truedat.XLSX.Reader

  @xlsx_path "test/fixtures/xlsx"

  defp xlsx_path(file) do
    Path.join(@xlsx_path, "#{file}.xlsx")
  end

  describe "read/2" do
    test "processes xlsx" do
      {:ok, result} =
        "upload_tiny"
        |> xlsx_path()
        |> Reader.read()

      assert %{
               "type_1" =>
                 {["external_id", "text" | _],
                  [
                    ["ex_id1", "text" | _],
                    ["ex_id2", "text2" | _],
                    ["ex_id3", "" | _]
                  ]}
             } = result
    end

    test "processes multiple sheets sequentially" do
      {:ok, result} =
        "upload"
        |> xlsx_path()
        |> Reader.read()

      assert is_map(result)

      assert %{
               "type_1" => {_, [_ | _] = type_1},
               "type_2" => {_, [_ | _] = type_2}
             } = result

      assert length(type_1) == 11
      assert length(type_2) == 10
    end

    test "handles empty sheets" do
      assert {:error, :empty_sheets} =
               "empty"
               |> xlsx_path()
               |> Reader.read()
    end

    test "handles XLSX file open errors" do
      assert {:error, "file not found"} = Reader.read("nonexistent.xlsx")
    end

    test "handles rows with missing columns by padding with empty strings" do
      {:ok, result} =
        "missing_column"
        |> xlsx_path()
        |> Reader.read()

      assert %{
               "type_1" =>
                 {[
                    "external_id",
                    "text",
                    "name",
                    "tech_name",
                    "alias_name",
                    "link_to_structure",
                    "domain",
                    "type",
                    "path",
                    "value1",
                    "value2",
                    "value3"
                  ],
                  [
                    [
                      "ex_id1",
                      "text",
                      "structure_1",
                      "tech_structure_1",
                      "alias_structure_1",
                      "http://test.truedat.io/structures/1",
                      "domain",
                      "type_1",
                      "system > structure_1",
                      "a",
                      "b",
                      "c"
                    ],
                    [
                      "ex_id2",
                      "text2",
                      "structure_2",
                      "tech_structure_2",
                      "alias_structure_2",
                      "http://test.truedat.io/structures/2",
                      "domain",
                      "type_1",
                      "system > structure_2",
                      "a",
                      "b",
                      nil
                    ],
                    [
                      "ex_id3",
                      "",
                      "structure_3",
                      "tech_structure_3",
                      "alias_structure_3",
                      "http://test.truedat.io/structures/3",
                      "domain",
                      "type_1",
                      "system > structure_3",
                      "a",
                      nil,
                      nil
                    ]
                  ]}
             } = result
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed XLSX files gracefully" do
      assert {:error, :invalid_format} =
               "invalid"
               |> xlsx_path()
               |> Reader.read()
    end

    test "handles sheets with only headers" do
      {:error, :empty_sheets} =
        "only_headers"
        |> xlsx_path()
        |> Reader.read()
    end

    test "handles sheets with empty rows" do
      {:ok, result} =
        "empty_rows"
        |> xlsx_path()
        |> Reader.read()

      assert %{
               "type_1" =>
                 {["external_id", "text" | _],
                  [
                    ["ex_id1", "text" | _],
                    ["ex_id3", "" | _]
                  ]}
             } = result
    end

    test "handles special characters in sheet names" do
      {:ok, result} =
        "special_character"
        |> xlsx_path()
        |> Reader.read()

      assert %{
               "spéciâl" =>
                 {[
                    "external_id",
                    "text",
                    "name",
                    "tech_name",
                    "alias_name",
                    "link_to_structure",
                    "domain",
                    "type",
                    "path",
                    "special_char"
                  ],
                  [
                    [
                      "ex_id1",
                      "text",
                      "structure_1",
                      "tech_structure_1",
                      "alias_structure_1",
                      "http://test.truedat.io/structures/1",
                      "domain",
                      "type_1",
                      "system > structure_1",
                      "spéciâl"
                    ]
                  ]}
             } = result
    end
  end
end
