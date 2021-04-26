defmodule TdDd.Cache.StructureEntryTest do
  use TdDd.DataCase

  alias TdDd.Cache.StructureEntry
  alias TdDd.DataStructures.RelationTypes

  @dsv_keys [:deleted_at, :group, :metadata, :name, :type, :updated_at]
  @ds_keys [:external_id, :system_id]
  @system_keys [:external_id, :id, :name]

  describe "StructureEntry.cache_entry/1" do
    test "returns an empty map for nil" do
      assert StructureEntry.cache_entry(nil) == %{}
    end

    test "returns a representation of a data structure" do
      %{data_structure_id: id, data_structure: ds} = dsv = insert(:data_structure_version)
      assert %{} = entry = StructureEntry.cache_entry(id)
      assert Map.take(entry, @dsv_keys) == Map.take(dsv, @dsv_keys)
      assert Map.take(entry, @ds_keys) == Map.take(ds, @ds_keys)
    end

    test "returns the system if the system option is true" do
      %{data_structure_id: id, data_structure: %{system: system}} =
        insert(:data_structure_version)

      assert %{system: actual} = StructureEntry.cache_entry(id, system: true)
      assert Map.take(actual, @system_keys) == Map.take(system, @system_keys)
    end

    test "returns the first parent if present" do
      %{id: relation_type_id} = RelationTypes.get_default()
      %{id: parent_id, data_structure_id: parent_structure_id} = insert(:data_structure_version)
      %{id: child_id, data_structure_id: id} = insert(:data_structure_version)

      insert(:data_structure_relation,
        child_id: child_id,
        parent_id: parent_id,
        relation_type_id: relation_type_id
      )

      assert %{parent_id: ^parent_structure_id} = StructureEntry.cache_entry(id)
    end
  end
end
