defmodule TdDd.DataStructures.PathsTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Paths
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo

  setup do
    hierarchy = create_hierarchy(["foo", "bar", "baz", "xyzzy", "spqr"])
    [hierarchy: hierarchy]
  end

  describe "Paths.with_path/2" do
    test "includes paths in inverse order" do
      paths =
        DataStructureVersion
        |> Paths.with_path(distinct: :data_structure_id)
        |> Repo.all()
        |> Enum.map(& &1.path.external_ids)

      assert length(paths) == 5
      assert ["foo"] in paths
      assert ["bar", "foo"] in paths
      assert ["baz", "bar", "foo"] in paths
      assert ["xyzzy", "baz", "bar", "foo"] in paths
      assert ["spqr", "xyzzy", "baz", "bar", "foo"] in paths
    end
  end

  describe "Paths.by_data_structure_id/2" do
    test "includes the path in inverse order", %{hierarchy: [foo, bar, baz, xyzzy, _]} do
      assert %{path: path} =
               DataStructureVersion
               |> Paths.by_data_structure_id(xyzzy.data_structure_id)
               |> Repo.one!()

      assert %{external_ids: external_ids, names: names, structure_ids: structure_ids} = path
      assert external_ids == ["xyzzy", "baz", "bar", "foo"]
      assert names == ["xyzzy", "baz", "bar", "foo"]
      assert structure_ids == [xyzzy, baz, bar, foo] |> Enum.map(& &1.data_structure_id)
    end

    test "uses the latest version of each structure the default parent path", %{
      hierarchy: [_, _, _, xyzzy, _]
    } do
      [foo2, bar2, baz2] = create_hierarchy(["foo2", "bar2", "baz2"], version: 1)

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: baz2.id,
        child_id: xyzzy.id,
        relation_type_id: relation_type_id
      )

      assert %{path: path} =
               DataStructureVersion
               |> Paths.by_data_structure_id(xyzzy.data_structure_id)
               |> Repo.one!()

      assert %{external_ids: external_ids, names: names, structure_ids: structure_ids} = path
      assert external_ids == ["xyzzy", "baz2", "bar2", "foo2"]
      assert names == ["xyzzy", "baz2", "bar2", "foo2"]
      assert structure_ids == [xyzzy, baz2, bar2, foo2] |> Enum.map(& &1.data_structure_id)
    end
  end

  describe "Paths.by_version_id/2" do
    test "includes the path in inverse order", %{hierarchy: [foo, bar, baz, xyzzy, _]} do
      assert %{path: path} =
               DataStructureVersion
               |> Paths.by_version_id(xyzzy.id)
               |> Repo.one!()

      assert %{external_ids: external_ids, names: names, structure_ids: structure_ids} = path
      assert external_ids == ["xyzzy", "baz", "bar", "foo"]
      assert names == ["xyzzy", "baz", "bar", "foo"]
      assert structure_ids == [xyzzy, baz, bar, foo] |> Enum.map(& &1.data_structure_id)
    end

    test "uses the latest version of each structure the default parent path", %{
      hierarchy: [_, _, _, xyzzy, _]
    } do
      [foo2, bar2, baz2] = create_hierarchy(["foo2", "bar2", "baz2"], version: 1)

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: baz2.id,
        child_id: xyzzy.id,
        relation_type_id: relation_type_id
      )

      assert %{path: path} =
               DataStructureVersion
               |> Paths.by_version_id(xyzzy.id)
               |> Repo.one!()

      assert %{external_ids: external_ids, names: names, structure_ids: structure_ids} = path
      assert external_ids == ["xyzzy", "baz2", "bar2", "foo2"]
      assert names == ["xyzzy", "baz2", "bar2", "foo2"]
      assert structure_ids == [xyzzy, baz2, bar2, foo2] |> Enum.map(& &1.data_structure_id)
    end
  end

  describe "Paths.by_structure_id_and_version/2" do
    test "includes the path in inverse order", %{hierarchy: [foo, bar, baz, xyzzy, _]} do
      assert %{path: path} =
               DataStructureVersion
               |> Paths.by_structure_id_and_version(xyzzy.data_structure_id, xyzzy.version)
               |> Repo.one!()

      assert %{external_ids: external_ids, names: names, structure_ids: structure_ids} = path
      assert external_ids == ["xyzzy", "baz", "bar", "foo"]
      assert names == ["xyzzy", "baz", "bar", "foo"]
      assert structure_ids == [xyzzy, baz, bar, foo] |> Enum.map(& &1.data_structure_id)
    end

    test "uses the latest version of each structure the default parent path", %{
      hierarchy: [_, _, _, xyzzy, _]
    } do
      [foo2, bar2, baz2] = create_hierarchy(["foo2", "bar2", "baz2"], version: 1)

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: baz2.id,
        child_id: xyzzy.id,
        relation_type_id: relation_type_id
      )

      assert %{path: path} =
               DataStructureVersion
               |> Paths.by_structure_id_and_version(xyzzy.data_structure_id, xyzzy.version)
               |> Repo.one!()

      assert %{external_ids: external_ids, names: names, structure_ids: structure_ids} = path
      assert external_ids == ["xyzzy", "baz2", "bar2", "foo2"]
      assert names == ["xyzzy", "baz2", "bar2", "foo2"]
      assert structure_ids == [xyzzy, baz2, bar2, foo2] |> Enum.map(& &1.data_structure_id)
    end
  end
end
