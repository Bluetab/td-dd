defmodule TdDd.DataStructures.RelationsTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.Relations

  setup do
    %{relation_type: type} = relation = insert(:data_structure_relation)
    [relation: relation, type: type]
  end

  describe "list_data_structure_relations/1" do
    test "lists all relations", %{relation: %{id: id}} do
      assert [%{id: ^id}] = Relations.list_data_structure_relations()
    end

    test "filters by updated_at", %{relation: %{updated_at: ts}} do
      assert [%{id: _}] = Relations.list_data_structure_relations(since: ts)
      assert [] = Relations.list_data_structure_relations(since: DateTime.add(ts, 1))
    end

    test "filters by id", %{relation: %{id: id}} do
      assert [%{id: ^id}] = Relations.list_data_structure_relations(min_id: id)
      assert [] = Relations.list_data_structure_relations(min_id: id + 1)
    end

    test "filters by types", %{type: %{name: type_name}} do
      assert [%{id: _}] = Relations.list_data_structure_relations(types: [type_name])
      assert [] = Relations.list_data_structure_relations(types: ["foo"])
    end
  end
end
