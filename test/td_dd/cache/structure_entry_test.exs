defmodule TdDd.Cache.StructureEntryTest do
  use TdDd.DataCase

  alias TdDd.Cache.StructureEntry
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes

  @moduletag sandbox: :shared
  @dsv_keys [:deleted_at, :group, :metadata, :name, :type, :updated_at]
  @ds_keys [:external_id, :system_id]
  @system_keys [:external_id, :id, :name]

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

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

    test "includes the path" do
      %{
        child: %{id: child_dsv_id, data_structure_id: id},
        parent: %{id: parent_dsv_id, data_structure_id: parent_id, name: parent_name}
      } = insert(:data_structure_relation, relation_type_id: RelationTypes.default_id!())

      Hierarchy.update_hierarchy([child_dsv_id, parent_dsv_id])

      assert %{path: []} = StructureEntry.cache_entry(parent_id)
      assert %{path: [^parent_name]} = StructureEntry.cache_entry(id)
    end

    test "includes the system if the system option is true" do
      %{data_structure_id: id, data_structure: %{system: system}} =
        insert(:data_structure_version)

      assert %{system: actual} = StructureEntry.cache_entry(id, system: true)
      assert Map.take(actual, @system_keys) == Map.take(system, @system_keys)
    end

    test "includes the first parent if present" do
      %{id: parent_id, data_structure_id: parent_structure_id} = insert(:data_structure_version)
      %{id: child_id, data_structure_id: id} = insert(:data_structure_version)

      insert(:data_structure_relation,
        child_id: child_id,
        parent_id: parent_id,
        relation_type_id: RelationTypes.default_id!()
      )

      assert %{parent_id: ^parent_structure_id} = StructureEntry.cache_entry(id)
    end

    test "includes original name and replaces name with alias if defined" do
      %{id: id} = insert(:data_structure, alias: nil)
      %{name: name} = insert(:data_structure_version, data_structure_id: id)
      assert %{original_name: ^name, name: ^name} = StructureEntry.cache_entry(id)

      %{id: id} = insert(:data_structure, alias: "some_alias")
      %{name: name} = insert(:data_structure_version, data_structure_id: id)
      assert %{original_name: ^name, name: "some_alias"} = StructureEntry.cache_entry(id)
    end
  end
end
