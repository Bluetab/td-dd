defmodule TdDd.LoaderTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.Graph
  alias TdDd.Loader
  alias TdDd.Search.MockIndexWorker

  setup_all do
    start_supervised(MockIndexWorker)
    :ok
  end

  describe "loader" do
    test "load/1 loads changes in data structures, fields and relations" do
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

      f11 = s1 |> Map.merge(f1)
      f12 = s1 |> Map.merge(f2)
      f13 = s1 |> Map.merge(f3)
      f21 = s2 |> Map.merge(f1)
      f32 = s3 |> Map.merge(f2)
      f41 = s4 |> Map.merge(f4)
      f51 = s5 |> Map.merge(f4)
      f61 = s6 |> Map.merge(f5)

      structure_records = [s1, s2, s3, s4, s5, s6]
      field_records = [f11, f12, f13, f21, f32, f41, f51, f61]
      relation_records = [r1, r2]

      assert {:ok, context} =
               Loader.load(
                 Graph.new(),
                 structure_records,
                 field_records,
                 relation_records,
                 audit()
               )
    end

    test "load/1 with structures containing an external_id" do
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

      f11 = s1 |> Map.merge(f1)
      f12 = s1 |> Map.merge(f2)
      f13 = s1 |> Map.merge(f3)
      f21 = s2 |> Map.merge(f1)
      f32 = s3 |> Map.merge(f2)

      structure_records = [s1, s2, s3]
      field_records = [f11, f12, f13, f21, f32]
      relation_records = [r1, r2]

      assert {:ok, context} =
               Loader.load(
                 Graph.new(),
                 structure_records,
                 field_records,
                 relation_records,
                 audit()
               )
    end

    test "load/1 with structures updates structures without generate version" do
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

      structure_records = [s1, s2]
      field_records = [f11]
      relation_records = [r1]

      assert {:ok, context} =
               Loader.load(
                 Graph.new(),
                 structure_records,
                 field_records,
                 relation_records,
                 audit()
               )

      v1 = DataStructures.get_latest_version_by_external_id(s1.external_id)
      v2 = DataStructures.get_latest_version_by_external_id(s2.external_id)

      v3 =
        DataStructures.get_latest_version_by_external_id(s1.external_id <> "/" <> f11.field_name)

      [m1, m2, m3] =
        Enum.map([v1, v2, v3], &DataStructures.get_latest_metadata_version(&1.data_structure_id))

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

      structure_records = [s1, s2]
      field_records = [f11]
      relation_records = [r1]

      assert {:ok, context} =
               Loader.load(
                 Graph.new(),
                 structure_records,
                 field_records,
                 relation_records,
                 audit()
               )

      v1 = DataStructures.get_latest_version_by_external_id(s1.external_id)
      v2 = DataStructures.get_latest_version_by_external_id(s2.external_id)

      v3 =
        DataStructures.get_latest_version_by_external_id(s1.external_id <> "/" <> f11.field_name)

      m1_deleted = m1

      [m1, m2, m3] =
        Enum.map([v1, v2, v3], &DataStructures.get_latest_metadata_version(&1.data_structure_id))

      assert v1.version == 1
      assert m1.version == 1
      assert m1.fields == %{"foo" => "bar2"}
      assert is_nil(m1.deleted_at)
      assert not is_nil(DataStructures.get_structure_metadata!(m1_deleted.id).deleted_at)

      assert v2.version == 0
      assert m2.version == 0
      assert m2.fields == %{"foo" => "bar"}
      assert is_nil(m2.deleted_at)

      assert v3.version == 0
      assert m3.version == 0
      assert m3.fields == %{"foo" => "bar"}
      assert is_nil(m3.deleted_at)
    end

    test "load/1 allows a fields's metadata to be set and updated" do
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = random_structure(system.id)
      field = structure |> random_field() |> Map.put(:metadata, %{"foo" => "bar"})

      assert {:ok, [structure_id]} = Loader.load(Graph.new(), [structure], [], [], audit())

      1..5
      |> Enum.each(fn _ ->
        foo = random_string("FOO")
        field = Map.put(field, :metadata, %{"foo" => foo})
        assert {:ok, _} = Loader.load(Graph.new(), [structure], [field], [], audit())

        %{data_fields: data_fields, children: children} =
          DataStructures.get_latest_version(structure_id, [:children, :data_fields])

        assert [%{metadata: %{"foo" => ^foo}}] = data_fields
        assert [%{metadata: %{"foo" => ^foo}}] = children
      end)
    end

    test "load/1 allows a structure's class to be set and updated" do
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = random_structure(system.id)

      1..5
      |> Enum.each(fn _ ->
        class = random_string()
        structure = Map.put(structure, :class, class)
        assert {:ok, _} = Loader.load(Graph.new(), [structure], [], [], audit())

        assert [%{latest: %{class: ^class}}] =
                 DataStructures.list_data_structures(
                   %{
                     external_id: structure.external_id
                   },
                   [:latest]
                 )
      end)
    end

    test "load/1 loads fails when structure has relation with itself" do
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

      relation = %{
        child_external_id: "xxx",
        parent_external_id: "xxx"
      }

      assert_raise(RuntimeError, fn ->
        Loader.load(Graph.new(), [structure], [], [relation], audit())
      end)
    end

    test "load/1 loads changes in relations with relation type" do
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
        Loader.load(
          Graph.new(),
          structure_records,
          [],
          relation_records,
          audit()
        )

      {:ok, _} =
        Loader.load(
          Graph.new(),
          structure_records,
          [],
          relation_records_with_type,
          audit()
        )

      ds1_last_version =
        %{}
        |> DataStructures.list_data_structures([:versions])
        |> Enum.filter(&(&1.id == ds1.id))
        |> hd
        |> DataStructures.get_latest_version()

      assert 2 == Map.get(ds1_last_version, :version)

      assert ["relation_type", "relation_type_2"] ==
               from(dsr in DataStructureRelation, where: dsr.parent_id == ^ds1_last_version.id)
               |> Repo.all()
               |> Repo.preload([:relation_type])
               |> Enum.map(&Map.get(&1, :relation_type))
               |> Enum.map(&Map.get(&1, :name))
    end
  end

  defp audit do
    ts = DateTime.truncate(DateTime.utc_now(), :second)

    %{last_change_by: 0, ts: ts}
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
    id = :rand.uniform(100_000_000)
    "#{prefix}#{id}"
  end
end
