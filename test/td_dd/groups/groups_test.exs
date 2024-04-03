defmodule TdDd.GroupsTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  alias TdDd.Groups

  setup_all do
    :ok
  end

  setup do
    [system: insert(:system)]
  end

  describe "TdDd.Group" do
    test "list_by_system/1 lists the current groups of a system", context do
      %{id: system_id, external_id: system_external_id} = context[:system]
      ts = DateTime.utc_now()
      ds1 = insert(:data_structure, system_id: system_id, external_id: "external_id1")
      ds2 = insert(:data_structure, system_id: system_id, external_id: "external_id2")

      insert(:data_structure_version, data_structure_id: ds1.id, group: "group_1", deleted_at: ts)
      insert(:data_structure_version, data_structure_id: ds1.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds2.id, group: "group_1", deleted_at: ts)
      insert(:data_structure_version, data_structure_id: ds2.id, version: 1, group: "group_2")

      assert Groups.list_by_system(system_external_id) == ["group_2"]
    end

    test "delete/2 deletes structure versions given and external_id and group_name", context do
      %{id: system_id, external_id: system_external_id} = context[:system]
      ds1 = insert(:data_structure, system_id: system_id, external_id: "external_id1")
      ds2 = insert(:data_structure, system_id: system_id, external_id: "external_id2")
      ds3 = insert(:data_structure, system_id: system_id, external_id: "external_id3")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds3.id, version: 0, group: "group_1")

      assert :ok = Groups.delete(system_external_id, "group_2")

      dsv1 = DataStructures.get_latest_version_by_external_id("external_id1")
      dsv2 = DataStructures.get_latest_version_by_external_id("external_id2")
      dsv3 = DataStructures.get_latest_version_by_external_id("external_id3")

      assert not is_nil(dsv1.deleted_at)
      assert not is_nil(dsv2.deleted_at)
      assert is_nil(dsv3.deleted_at)
    end
  end
end
