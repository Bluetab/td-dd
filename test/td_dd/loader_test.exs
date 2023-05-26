defmodule TdDd.LoaderTest do
  use TdDd.DataCase

  import Ecto.Query
  import ExUnit.CaptureLog
  import TdDd.TestOperators

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.Loader
  alias TdDd.Repo

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  describe "load/1" do
    test "handles empty list of structures" do
      records = %{structures: []}
      assert {:ok, _context} = Loader.load(records, audit())
    end

    test "loads changes in data structures, fields and relations" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")
      sys2 = insert(:system, external_id: "SYS2", name: "SYS2")

      ds1 = insert(:data_structure, system_id: sys1.id)
      ds2 = insert(:data_structure, system_id: sys1.id)

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        group: "GROUP1",
        name: "NAME1",
        type: "USER_TABLE",
        version: 0
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        group: "GROUP6",
        name: "NAME6",
        type: "USER_TABLE",
        version: 0
      )

      s1 = %{
        description: "D1",
        external_id: ds1.external_id,
        group: "GROUP1",
        name: "NAME1",
        system_id: sys1.id,
        type: "USER_TABLE",
        version: 0
      }

      s2 = %{
        description: "D2",
        external_id: random_string(),
        group: "GROUP2",
        name: "NAME2",
        system_id: sys1.id,
        type: "VIEW",
        version: 0
      }

      s3 = %{
        description: "D3",
        external_id: random_string(),
        group: "GROUP3",
        name: "NAME3",
        system_id: sys2.id,
        type: "Report",
        version: 0
      }

      s4 = %{
        description: "D4",
        external_id: random_string(),
        group: "GROUP3",
        name: "NAME4",
        system_id: sys2.id,
        type: "Folder",
        version: 22
      }

      s5 = %{
        description: "D4",
        external_id: random_string(),
        group: "GROUP3",
        name: "NAME4",
        system_id: sys2.id,
        type: "Dimension",
        version: 23
      }

      s6 = %{
        description: nil,
        external_id: random_string(),
        group: "GROUP6",
        name: "NAME6",
        system_id: sys1.id,
        type: "USER_TABLE",
        version: 1
      }

      r1 = %{
        system_id: s1.system_id,
        parent_group: s1.group,
        parent_external_id: s1.external_id,
        parent_name: s1.name,
        child_group: s2.group,
        child_name: s2.name,
        child_external_id: s2.external_id
      }

      r2 = %{
        system_id: s3.system_id,
        parent_group: s3.group,
        parent_external_id: s3.external_id,
        parent_name: s3.name,
        child_group: s4.group,
        child_name: s4.name,
        child_external_id: s4.external_id
      }

      f1 = %{
        field_name: "F1",
        type: "T1",
        nullable: false,
        precision: "P1",
        description: "D1NEW",
        version: 0
      }

      f2 = %{
        field_name: "F2",
        type: "NEWTYPE2",
        nullable: true,
        precision: "P2",
        description: "NEWDES2",
        version: 0,
        metadata: %{foo: "bar"}
      }

      f3 = %{
        field_name: "KZTLF",
        type: "CHAR",
        nullable: true,
        precision: "1,0",
        description: "Nueva descripción",
        version: 0
      }

      f4 = %{
        field_name: "Field x",
        type: "CHAR",
        nullable: true,
        precision: "1,0",
        description: "Nueva descripción"
      }

      f5 = %{
        field_name: "FIELD_TO_KEEP",
        type: "T2",
        description: "Will be kept",
        precision: "P2",
        nullable: false,
        version: 1
      }

      f11 = Map.merge(s1, f1)
      f12 = Map.merge(s1, f2)
      f13 = Map.merge(s1, f3)
      f21 = Map.merge(s2, f1)
      f32 = Map.merge(s3, f2)
      f41 = Map.merge(s4, f4)
      f51 = Map.merge(s5, f4)
      f61 = Map.merge(s6, f5)

      records = %{
        structures: [s1, s2, s3, s4, s5, s6],
        fields: [f11, f12, f13, f21, f32, f41, f51, f61],
        relations: [r1, r2]
      }

      assert {:ok, _context} = Loader.load(records, audit())
    end

    test "loads works with classifier" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")

      insert(:classifier, system_id: sys1.id)

      ds1 = insert(:data_structure, system_id: sys1.id)

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        group: "GROUP1",
        name: "NAME1",
        type: "USER_TABLE",
        version: 0
      )

      s1 = %{
        description: "D1",
        external_id: ds1.external_id,
        group: "GROUP1",
        name: "NAME1",
        system_id: sys1.id,
        type: "USER_TABLE",
        version: 0
      }

      records = %{
        structures: [s1],
        fields: [],
        relations: []
      }

      initial_hierarchy = Hierarchy.list_hierarchy()
      assert {:ok, _context} = Loader.load(records, audit())
      assert Enum.count(initial_hierarchy) != Enum.count(Hierarchy.list_hierarchy())
    end

    test "with structures containing an external_id" do
      system = insert(:system, external_id: "SYS1", name: "SYS1")
      insert(:system, external_id: "SYS2", external_id: "SYS2")

      data_structure = insert(:data_structure, system_id: system.id, external_id: "EXT1")

      insert(:data_structure_version,
        data_structure_id: data_structure.id,
        group: "GROUP1",
        name: "NAME1",
        type: "Table",
        version: 0
      )

      s1 = %{
        system_id: system.id,
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        version: 0,
        external_id: "EXT1",
        type: "Table"
      }

      s2 = %{
        system_id: system.id,
        group: "GROUP1",
        name: "NAME2",
        description: "D1",
        version: 0,
        external_id: "EXT2",
        type: "View"
      }

      s3 = %{
        system_id: system.id,
        group: "GROUP2",
        name: "NAME3",
        description: "D2",
        version: 0,
        external_id: "EXT3",
        type: "Report"
      }

      r1 = %{
        system_id: system.id,
        parent_group: "GROUP1",
        parent_external_id: "EXT1",
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2",
        child_external_id: "EXT2"
      }

      r2 = %{
        system_id: system.id,
        parent_group: "GROUP1",
        parent_name: "NAME2",
        parent_external_id: "EXT2",
        child_group: "GROUP2",
        child_name: "NAME3",
        child_external_id: "EXT3"
      }

      f1 = %{
        field_name: "F1",
        type: "T1",
        nullable: false,
        precision: "P1",
        description: "D1NEW",
        version: 0
      }

      f2 = %{
        field_name: "F2",
        type: "NEWTYPE2",
        nullable: true,
        precision: "P2",
        description: "NEWDES2",
        version: 0,
        metadata: %{foo: "bar"}
      }

      f3 = %{
        field_name: "KZTLF",
        type: "CHAR",
        nullable: true,
        precision: "1,0",
        description: "Nueva descripción",
        version: 0
      }

      f11 = Map.merge(s1, f1)
      f12 = Map.merge(s1, f2)
      f13 = Map.merge(s1, f3)
      f21 = Map.merge(s2, f1)
      f32 = Map.merge(s3, f2)

      assert {:ok, _context} =
               Loader.load(
                 %{
                   structures: [s1, s2, s3],
                   fields: [f11, f12, f13, f21, f32],
                   relations: [r1, r2]
                 },
                 audit()
               )
    end

    setup :create_source

    test "update structures without generate version", %{source: source} do
      system = insert(:system, external_id: "SYS1", name: "SYS1")

      s1 = %{
        system_id: system.id,
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        external_id: "EXT1",
        type: "Table",
        metadata: %{"bar" => "baz"},
        mutable_metadata: %{"foo" => "bar"}
      }

      s2 = %{
        system_id: system.id,
        group: "GROUP1",
        name: "NAME2",
        description: "D1",
        version: 0,
        external_id: "EXT2",
        type: "View"
      }

      r1 = %{
        system_id: system.id,
        parent_group: "GROUP1",
        parent_external_id: "EXT1",
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2",
        child_external_id: "EXT2"
      }

      f1 = %{
        field_name: "F1",
        type: "T1",
        nullable: false,
        precision: "P1",
        description: "D1NEW",
        version: 0
      }

      f11 = Map.merge(s1, f1)

      assert {:ok, _context} =
               Loader.load(
                 %{
                   structures: [s1, s2],
                   fields: [f11],
                   relations: [r1]
                 },
                 audit()
               )

      v1 = DataStructures.get_latest_version_by_external_id(s1.external_id)
      v2 = DataStructures.get_latest_version_by_external_id(s2.external_id)

      v3 =
        DataStructures.get_latest_version_by_external_id(s1.external_id <> "/" <> f11.field_name)

      [m1, m2, m3] = Enum.map([v1, v2, v3], &DataStructures.get_metadata_version/1)

      assert Enum.all?([v1, v2, v3], &(&1.version == 0))

      assert m1.version == 0
      assert m1.fields == %{"foo" => "bar"}

      assert is_nil(m2)

      assert m3.version == 0
      assert m3.fields == %{"foo" => "bar"}

      s1 =
        s1
        |> Map.put(:description, "blah")
        |> Map.put(:mutable_metadata, %{"foo" => "bar2"})

      s2 = Map.put(s2, :mutable_metadata, %{"foo" => "bar"})
      f11 = Map.put(f11, :mutable_metadata, %{"foo" => "bar"})

      assert {:ok, _context} =
               Loader.load(
                 %{
                   structures: [s1, s2],
                   fields: [f11],
                   relations: [r1]
                 },
                 audit(),
                 source: source.external_id
               )

      v1 = DataStructures.get_latest_version_by_external_id(s1.external_id)
      v2 = DataStructures.get_latest_version_by_external_id(s2.external_id)

      v3 =
        DataStructures.get_latest_version_by_external_id(s1.external_id <> "/" <> f11.field_name)

      m1_deleted = m1

      [m1, m2, m3] = Enum.map([v1, v2, v3], &DataStructures.get_metadata_version/1)

      [s1, s2, s3] =
        Enum.map([v1, v2, v3], &DataStructures.get_data_structure!(&1.data_structure_id))

      assert v1.version == 1
      assert m1.version == 1
      assert m1.fields == %{"foo" => "bar2"}
      assert s1.source_id == source.id
      assert is_nil(m1.deleted_at)
      refute is_nil(DataStructures.get_structure_metadata!(m1_deleted.id).deleted_at)

      assert v2.version == 0
      assert m2.version == 0
      assert m2.fields == %{"foo" => "bar"}
      assert s2.source_id == source.id
      assert is_nil(m2.deleted_at)

      assert v3.version == 0
      assert m3.version == 0
      assert m3.fields == %{"foo" => "bar"}
      assert s3.source_id == source.id
      assert is_nil(m3.deleted_at)
    end

    test "allows a fields's metadata to be set and updated" do
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = random_structure(system.id)
      field = structure |> random_field() |> Map.put(:metadata, %{"foo" => "bar"})

      assert {:ok, %{insert_versions: {1, [%{data_structure_id: structure_id}]}}} =
               Loader.load(%{structures: [structure]}, audit())

      1..5
      |> Enum.each(fn _ ->
        foo = random_string("FOO")
        field = Map.put(field, :metadata, %{"foo" => foo})

        assert {:ok, _} = Loader.load(%{structures: [structure], fields: [field]}, audit())

        %{data_fields: data_fields, children: children} =
          DataStructures.get_latest_version(structure_id, [:children, :data_fields])

        assert [%{metadata: %{"foo" => ^foo}}] = data_fields
        assert [%{metadata: %{"foo" => ^foo}}] = children
      end)
    end

    test "allows a structure's class to be set and updated" do
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = random_structure(system.id)

      for class <- Enum.map(1..5, fn _ -> random_string() end) do
        structure = Map.put(structure, :class, class)
        assert {:ok, %{structure_ids: [id]}} = Loader.load(%{structures: [structure]}, audit())
        assert %{class: ^class} = DataStructures.get_latest_version(id)
      end
    end

    test "loads fails when structure has relation with itself" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")

      structure = %{
        description: "Table with country information",
        external_id: "xxx",
        group: "demo",
        metadata: %{},
        name: "xxx",
        ou: "Trial Truedat",
        system_id: sys1.id,
        type: "Table",
        version: 0
      }

      relation = %{child_external_id: "xxx", parent_external_id: "xxx"}

      assert capture_log(fn ->
               {:error, :graph, "reflexive relations are not permitted (xxx)",
                %{} = _changes_so_far} =
                 Loader.load(%{structures: [structure], relations: [relation]}, audit())
             end) =~ "reflexive relations are not permitted (xxx)"
    end

    test "loads changes in relations with relation type" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")
      insert(:relation_type, name: "relation_type")
      insert(:relation_type, name: "relation_type_2")

      ds1 = insert(:data_structure, system_id: sys1.id)
      ds2 = insert(:data_structure, system_id: sys1.id)

      insert(:data_structure_version,
        data_structure_id: ds1.id,
        group: "GROUP1",
        name: "NAME1",
        type: "USER_TABLE",
        version: 0
      )

      insert(:data_structure_version,
        data_structure_id: ds2.id,
        group: "GROUP6",
        name: "NAME2",
        type: "USER_TABLE",
        version: 0
      )

      s1 = %{
        external_id: ds1.external_id,
        group: "GROUP1",
        name: "NAME1",
        type: "USER_TABLE",
        system_id: sys1.id
      }

      s2 = %{
        external_id: ds2.external_id,
        group: "GROUP6",
        name: "NAME2",
        type: "USER_TABLE",
        system_id: sys1.id
      }

      r1 = %{
        parent_external_id: ds1.external_id,
        child_external_id: ds2.external_id
      }

      r1_with_type = %{
        parent_external_id: ds1.external_id,
        child_external_id: ds2.external_id,
        relation_type_name: "relation_type"
      }

      r2_with_type = %{
        parent_external_id: ds1.external_id,
        child_external_id: ds2.external_id,
        relation_type_name: "relation_type_2"
      }

      structure_records = [s1, s2]
      relation_records = [r1]
      relation_records_with_type = [r1_with_type, r2_with_type]

      {:ok, _} =
        Loader.load(%{structures: structure_records, relations: relation_records}, audit())

      {:ok, _} =
        Loader.load(
          %{structures: structure_records, relations: relation_records_with_type},
          audit()
        )

      assert %{id: dsv1_id, version: 2} =
               DataStructures.get_latest_version_by_external_id(ds1.external_id)

      relation_types =
        DataStructureRelation
        |> where([dsr], dsr.parent_id == ^dsv1_id)
        |> join(:inner, [dsr], relation_type in assoc(dsr, :relation_type))
        |> select([_, t], t.name)
        |> order_by([_, t], t.name)
        |> Repo.all()

      assert relation_types == ["relation_type", "relation_type_2"]
    end

    test "loads all subtree when it is recovered from a deletion and there are no changes" do
      sys = insert(:system, external_id: "SYS1", name: "SYS1")

      s1 = %{
        external_id: "EXT1",
        group: "GROUP1",
        name: "NAME1",
        type: "USER_TABLE",
        system_id: sys.id
      }

      s2 = %{
        external_id: "EXT2",
        group: "GROUP6",
        name: "NAME2",
        type: "USER_TABLE",
        system_id: sys.id
      }

      s3 = %{
        external_id: "EXT3",
        group: "GROUP3",
        name: "NAME3",
        type: "USER_TABLE",
        system_id: sys.id
      }

      s4 = %{
        external_id: "EXT4",
        group: "GROUP4",
        name: "NAME4",
        type: "USER_TABLE",
        system_id: sys.id
      }

      r1 = %{
        parent_external_id: s1.external_id,
        child_external_id: s2.external_id
      }

      r2 = %{
        parent_external_id: s3.external_id,
        child_external_id: s4.external_id
      }

      {:ok, _} = Loader.load(%{structures: [s1, s2, s3, s4], relations: [r1, r2]}, audit())
      {:ok, _} = Loader.load(%{structures: [s1, s2], relations: [r1]}, audit())
      {:ok, _} = Loader.load(%{structures: [s1, s2, s3, s4], relations: [r1, r2]}, audit())

      assert Enum.all?([s3, s4], fn %{external_id: external_id} ->
               %{version: version, deleted_at: deleted_at} =
                 DataStructures.get_latest_version_by_external_id(external_id)

               version == 0 and is_nil(deleted_at)
             end)
    end

    test "when external_id and parent_external_id provided" do
      external_id = "parent_external_id"
      child_external_id = "child_external_id"
      sys = insert(:system, external_id: "SYS1", name: "SYS1")
      ds = insert(:data_structure, external_id: external_id, system_id: sys.id)
      version = insert(:data_structure_version, data_structure_id: ds.id)

      s1 = %{
        external_id: ds.external_id,
        group: version.group,
        name: version.name,
        type: version.type,
        system_id: sys.id
      }

      s2 = %{
        external_id: child_external_id,
        group: "CHILD_GROUP",
        name: "NAME2",
        type: version.type,
        system_id: sys.id
      }

      r1 = %{
        parent_external_id: s1.external_id,
        child_external_id: s2.external_id
      }

      {:ok, _} = Loader.load(%{structures: [s1, s2], relations: [r1]}, audit())

      assert %DataStructureVersion{children: [child | _]} =
               DataStructures.get_latest_version_by_external_id(external_id, enrich: [:children])

      data_structure_version = DataStructures.get_latest_version_by_external_id(child_external_id)
      assert data_structure_version <~> child
    end

    test "restores an unchanged, deleted structure" do
      system = insert(:system, external_id: "SYS1", name: "SYS1")

      s1 = %{
        system_id: system.id,
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        external_id: "EXT1",
        type: "Table",
        metadata: %{"bar" => "baz"},
        mutable_metadata: %{"foo" => "bar"}
      }

      assert {:ok, multi} = Loader.load(%{structures: [s1]}, audit())
      assert %{insert_versions: {1, [%{id: id}]}} = multi

      assert %{ts: ts} = audit()

      assert {1, [^id]} =
               DataStructureVersion
               |> select([ds], ds.id)
               |> where(id: ^id)
               |> update(set: [deleted_at: ^ts])
               |> Repo.update_all([])

      assert {:ok, multi} = Loader.load(%{structures: [s1]}, audit())
      assert %{restore_versions: {1, [_]}} = multi
      assert %{deleted_at: nil} = Repo.get(DataStructureVersion, id)
    end

    test "updates ghash and deleted_at if lhash is unchanged" do
      %{id: system_id} = insert(:system, external_id: "SYS1", name: "SYS1")

      s1 = %{
        system_id: system_id,
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        external_id: "EXT1",
        type: "Table",
        metadata: %{"bar" => "baz"},
        mutable_metadata: %{"foo" => "bar"}
      }

      s2 = %{s1 | external_id: "EXT2", name: "NAME2"}
      s3 = %{s1 | external_id: "EXT3", name: "NAME3"}
      r12 = %{parent_external_id: "EXT1", child_external_id: "EXT2"}
      r23 = %{parent_external_id: "EXT2", child_external_id: "EXT3"}

      assert {:ok, multi} =
               Loader.load(%{structures: [s1, s2, s3], relations: [r12, r23]}, audit())

      assert %{insert_versions: {3, [%{id: id1}, %{id: id2}, %{id: id3}]}} = multi
      assert %{ghash: ghash1} = Repo.get(DataStructureVersion, id1)

      assert %{ts: ts} = audit()

      assert {3, _} =
               DataStructureVersion
               |> select([ds], ds.id)
               |> where([ds], ds.id in ^[id1, id2, id3])
               |> update(set: [deleted_at: ^ts])
               |> Repo.update_all([])

      s3 = %{s3 | name: "CHANGED"}

      assert {:ok, multi} =
               Loader.load(%{structures: [s1, s2, s3], relations: [r12, r23]}, audit())

      assert %{update_versions: {1, [%{id: ^id1}]}} = multi
      assert %{deleted_at: nil, ghash: ghash2} = Repo.get(DataStructureVersion, id1)
      refute ghash1 == ghash2
    end
  end

  describe "system_ids/1" do
    test "returns a unique list of system ids" do
      records = 1..15 |> Enum.map(fn id -> %{system_id: Integer.mod(id, 10)} end)
      assert Loader.system_ids(records) ||| 0..9
    end
  end

  describe "metadata_multi/4" do
    test "identifies missing external_ids" do
      system1 = insert(:system)
      %{system: _not_system1} = insert(:data_structure, external_id: "exists_in_another_system")
      records = [%{external_id: "doesnt_exist"}, %{external_id: "exists_in_another_system"}]

      assert {:error, :missing_external_ids, [_, _], %{}} =
               Loader.metadata_multi(records, system1, audit())
    end

    test "replaces metadata with nil" do
      %{data_structure: %{id: id, system: system, external_id: external_id}} =
        insert(:structure_metadata)

      records = [%{external_id: external_id, mutable_metadata: nil}]

      assert {:ok, %{replace_metadata: [_], structure_ids: [^id]}} =
               Loader.metadata_multi(records, system, audit())
    end

    test "replaces metadata with new value" do
      %{data_structure: %{id: id, system: system, external_id: external_id}} =
        insert(:structure_metadata)

      records = [%{external_id: external_id, mutable_metadata: %{"xyzzy" => "spqr"}}]

      assert {:ok, %{replace_metadata: [^id], structure_ids: [^id]}} =
               Loader.metadata_multi(records, system, audit())
    end

    test "retains metadata with same value" do
      fields = %{"foo" => "bar", "bar" => ["baz"]}

      %{data_structure: %{system: system, external_id: external_id}} =
        insert(:structure_metadata, fields: fields)

      records = [%{external_id: external_id, mutable_metadata: fields}]

      assert {:ok, %{replace_metadata: [], structure_ids: []}} =
               Loader.metadata_multi(records, system, audit())
    end

    test "merges new metadata with existing value" do
      %{data_structure: %{id: id, system: system, external_id: external_id}} =
        insert(:structure_metadata)

      %{data_structure: %{external_id: external_id2}, fields: existing_metadata} =
        insert(:structure_metadata, data_structure: build(:data_structure, system: system))

      records = [
        %{external_id: external_id, mutable_metadata: %{"xyzzy" => "spqr"}},
        %{external_id: external_id2, mutable_metadata: existing_metadata}
      ]

      assert {:ok, %{merge_metadata: [^id], structure_ids: [^id]}} =
               Loader.metadata_multi(records, system, audit(), "merge")
    end
  end

  defp audit do
    %{last_change_by: 0, ts: DateTime.utc_now()}
  end

  defp create_source(_) do
    [source: insert(:source)]
  end

  defp random_structure(system_id) do
    %{
      system_id: system_id,
      group: random_string("GROUP"),
      name: random_string("NAME"),
      description: random_string("DESC"),
      version: 0,
      external_id: random_string("EXT"),
      type: "Type"
    }
  end

  defp random_field(structure) do
    Map.merge(structure, %{
      field_name: random_string("FIELD "),
      type: "CHAR",
      description: random_string("DESC"),
      version: 0
    })
  end

  defp random_string(prefix \\ "") do
    id = System.unique_integer([:positive])
    "#{prefix}#{id}"
  end
end
