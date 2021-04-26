defmodule TdDd.DataStructures.AncestryTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.Ancestry

  describe "TdDd.DataStructures.Ancestry" do
    test "get_descendent_ids/1 returns all descendents for a given external_id" do
      dsvs = create_hierarchy(["foo", "bar", "baz", "xyzzy"])
      assert ids = Ancestry.get_descendent_ids("foo")
      assert Enum.count(ids) == 4
      assert ids == Enum.map(dsvs, & &1.data_structure_id)
    end

    test "get_ancestor_records/2 with an external_id returns records for current ancestors and their children" do
      create_hierarchy(["foo", "bar", "baz", "xyzzy"])
      assert {structure_records, relation_records} = Ancestry.get_ancestor_records("xyzzy", nil)
      structure_ids = Enum.map(structure_records, fn {id, _} -> id end)
      assert structure_ids == ["baz", "bar", "foo"]

      assert relation_records == [
               %{child_external_id: "baz", parent_external_id: "bar"},
               %{child_external_id: "bar", parent_external_id: "foo"}
             ]
    end

    test "get_ancestor_records/2 with an external_id and parent_external_id returns records for as-is and to-be ancestors" do
      create_hierarchy(["FOO", "BAR", "BAZ", "XYZZY"])
      create_hierarchy(["foo", "bar", "baz", "xyzzy"])

      # reparent baz from bar to BAR
      assert {structure_records, relation_records} = Ancestry.get_ancestor_records("baz", "BAR")
      structure_ids = Enum.map(structure_records, fn {id, _} -> id end)
      assert structure_ids == ["bar", "foo", "BAR", "FOO", "BAZ"]

      assert relation_records == [
               %{child_external_id: "baz", parent_external_id: "BAR"},
               %{child_external_id: "bar", parent_external_id: "foo"},
               %{child_external_id: "BAZ", parent_external_id: "BAR"},
               %{child_external_id: "BAR", parent_external_id: "FOO"}
             ]
    end
  end
end
