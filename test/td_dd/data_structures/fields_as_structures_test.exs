defmodule TdDd.Loader.FieldsAsStructuresTest do
  use TdDd.DataCase
  alias TdDd.CSV.Reader
  alias TdDd.Loader.FieldsAsStructures

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
  @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]
  @system_id 123
  @domain_map %{"Truedat" => 42}

  setup context do
    case Map.get(context, :fixture) do
      nil ->
        :ok

      fixture ->
        {:ok, structures} = read_structures(fixture <> "/structures.csv")
        {:ok, fields} = read_fields(fixture <> "/fields.csv")

        {:ok, structures: structures, fields: fields}
    end
  end

  defp read_structures(path) do
    path
    |> File.stream!()
    |> Reader.read_csv(
      domain_map: @domain_map,
      defaults: %{system_id: @system_id, version: 0},
      schema: @structure_import_schema,
      required: @structure_import_required
    )
  end

  defp read_fields(path) do
    path
    |> File.stream!()
    |> Reader.read_csv(
      defaults: %{version: 0, external_id: nil, system_id: @system_id},
      schema: @field_import_schema,
      required: @field_import_required,
      booleans: ["nullable"]
    )
  end

  describe "TdDd.Loader.FieldsAsStructures" do
    @tag fixture: "test/fixtures/fields_as_structures"
    test "converts fields into structures", %{structures: structures, fields: fields} do
      assert Enum.count(structures) == 4
      assert Enum.count(fields) == 58

      fields_by_parent = FieldsAsStructures.group_by_parent(fields, structures)
      assert Enum.count(fields_by_parent) == 2

      fields_as_structures = FieldsAsStructures.as_structures(fields_by_parent)
      assert Enum.count(fields_as_structures) == 58

      fields_as_relations = FieldsAsStructures.as_relations(fields_by_parent)
      assert Enum.count(fields_as_relations) == 58
    end

    test "identifies columns" do
      table = %{type: "USER_TABLE"}
      report = %{type: "REPORT"}
      view = %{type: "Some type with the word view in it"}
      child1 = %{metadata: %{type: "Foo"}}
      child2 = %{}

      assert FieldsAsStructures.child_type(table, child1) == "Column"
      assert FieldsAsStructures.child_type(report, child1) == "Foo"
      assert FieldsAsStructures.child_type(report, child2) == "Field"
      assert FieldsAsStructures.child_type(view, child2) == "Column"
    end
  end
end
