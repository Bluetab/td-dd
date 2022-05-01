defmodule TdDd.Lineage.Import.ReaderTest do
  use ExUnit.Case

  alias TdDd.Lineage.Import.Reader
  alias TdDd.Lineage.Import.Validations

  describe "TdDd.Lineage.Import.Reader" do
    test "returns a graph if data is valid" do
      nodes_path = "test/fixtures/lineage/nodes.csv"
      rels_path = "test/fixtures/lineage/rels.csv"
      assert {:ok, %Graph{}} = Reader.read(nodes_path, rels_path)
    end

    test "returns a graph if data is valid with metadata" do
      nodes_path = "test/fixtures/lineage/metadata/nodes.csv"
      rels_path = "test/fixtures/lineage/metadata/rels.csv"
      assert {:ok, %Graph{}} = Reader.read(nodes_path, rels_path)
    end

    test "returns information about validation errors" do
      nodes_path = "test/fixtures/lineage/validations/nodes.csv"
      rels_path = "test/fixtures/lineage/validations/rels.csv"

      assert %Validations{
               valid: false,
               contained_by_many: ["Group3", "Resource1"],
               contained_by_none: ["Resource2"],
               invalid_contains: [%{v1: "Resource1", v2: "Resource2"}],
               invalid_depends: [%{v1: "Group1", v2: "Group2"}],
               invalid_edge_class: ["InvalidEdgeType"],
               invalid_node_class: ["InvalidNodeLabel"]
             } = Reader.read(nodes_path, rels_path)
    end
  end
end
