defmodule TdDd.DataStructures.PatchCacheTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.PathCache
  alias TdDd.DataStructures.RelationTypes

  setup_all do
    start_supervised(PathCache)
    :ok
  end

  describe "TdDd.DataStructures.PathCache" do
    test "path/1 returns the path of a data structure version" do
      dsvs = create_hierarchy(["foo", "bar", "baz", "xyzzy"])
      PathCache.refresh()
      paths = Enum.map(dsvs, &PathCache.path(&1.id))
      assert paths == [[], ["foo"], ["foo", "bar"], ["foo", "bar", "baz"]]
    end

    test "path/1 returns path structures of default relation type" do
      %{id: system_id} = insert(:system)

      p =
        insert(:data_structure_version,
          name: "dsv1",
          data_structure: build(:data_structure, external_id: "dsv1", system_id: system_id)
        )

      c1 =
        insert(:data_structure_version,
          name: "c1",
          data_structure: build(:data_structure, external_id: "c1", system_id: system_id)
        )

      versions =
        Enum.map(
          2..50,
          &insert(:data_structure_version,
            name: "c#{&1}",
            data_structure: build(:data_structure, external_id: "c#{&1}", system_id: system_id)
          )
        )

      %{id: default_type_id} = RelationTypes.get_default()
      %{id: custom_id} = insert(:relation_type, name: "relation_type_1")

      Enum.each(
        versions,
        &insert(:data_structure_relation,
          parent_id: &1.id,
          child_id: c1.id,
          relation_type_id: custom_id
        )
      )

      insert(:data_structure_relation,
        parent_id: p.id,
        child_id: c1.id,
        relation_type_id: default_type_id
      )

      PathCache.refresh()
      assert PathCache.path(c1.id) == [p.name]
    end
  end
end
