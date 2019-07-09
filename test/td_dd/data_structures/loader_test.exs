defmodule TdDd.LoaderTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  alias TdDd.Loader
  alias TdDd.Repo
  alias TdDd.Search.MockIndexWorker

  setup_all do
    start_supervised(MockIndexWorker)
    :ok
  end

  describe "loader" do
    test "load/1 loads changes in data structures, fields and relations" do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")
      sys2 = insert(:system, external_id: "SYS2", name: "SYS2")

      data_structure =
        insert(:data_structure,
          system_id: sys1.id,
          group: "GROUP1",
          name: "NAME1",
          type: "USER_TABLE"
        )

      ds_2 =
        insert(:data_structure,
          system_id: sys1.id,
          group: "GROUP6",
          name: "NAME6",
          type: "USER_TABLE"
        )

      dsv = insert(:data_structure_version, data_structure_id: data_structure.id, version: 0)
      dsv2 = insert(:data_structure_version, data_structure_id: ds_2.id, version: 0)

      field1 =
        insert(:data_field,
          name: "F1",
          type: "T1",
          description: "Field1",
          precision: "P1",
          nullable: false
        )

      field2 =
        insert(:data_field,
          name: "F2",
          type: "T2",
          description: "Field2",
          precision: "P2",
          nullable: true
        )

      field3 =
        insert(:data_field,
          name: "F123123",
          type: "T2",
          description: "Will be deleted",
          precision: "P2",
          nullable: false
        )

      field4 =
        insert(:data_field,
          name: "FIELD_TO_KEEP",
          type: "T2",
          description: "Will be kept",
          precision: "P2",
          nullable: false
        )

      entries =
        [field1, field2, field3]
        |> Enum.map(fn %{id: id} -> %{data_field_id: id, data_structure_version_id: dsv.id} end)

      Repo.insert_all("versions_fields", entries)

      entries =
        [field4]
        |> Enum.map(fn %{id: id} -> %{data_field_id: id, data_structure_version_id: dsv2.id} end)

      Repo.insert_all("versions_fields", entries)

      s1 = %{
        description: "D1",
        external_id: nil,
        group: "GROUP1",
        name: "NAME1",
        system_id: sys1.id,
        type: "USER_TABLE",
        version: 0
      }

      s2 = %{
        description: "D2",
        external_id: nil,
        group: "GROUP2",
        name: "NAME2",
        system_id: sys1.id,
        type: "VIEW",
        version: 0
      }

      s3 = %{
        description: "D3",
        external_id: nil,
        group: "GROUP3",
        name: "NAME3",
        system_id: sys2.id,
        type: "Report",
        version: 0
      }

      s4 = %{
        description: "D4",
        external_id: nil,
        group: "GROUP3",
        name: "NAME4",
        system_id: sys2.id,
        type: "Folder",
        version: 22
      }

      s5 = %{
        description: "D4",
        external_id: nil,
        group: "GROUP3",
        name: "NAME4",
        system_id: sys2.id,
        type: "Dimension",
        version: 23
      }

      s6 = %{
        description: nil,
        external_id: nil,
        group: "GROUP6",
        name: "NAME6",
        system_id: sys1.id,
        type: "USER_TABLE",
        version: 1
      }

      r1 = %{
        system_id: sys1.id,
        parent_group: "GROUP1",
        parent_external_id: nil,
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2",
        child_external_id: nil
      }

      r2 = %{
        system_id: sys2.id,
        parent_group: "GROUP3",
        parent_external_id: nil,
        parent_name: "NAME3",
        child_group: "GROUP3",
        child_name: "NAME4",
        child_external_id: nil
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
               Loader.load(structure_records, field_records, relation_records, audit())

      assert %{added: added, removed: removed, modified: modified, kept: kept} = context
      assert added == 6
      assert removed == 2
      assert modified == 1
      assert kept == 1
    end

    test "load/1 with structures containing an external_id" do
      system = insert(:system, external_id: "SYS1", name: "SYS1")
      insert(:system, external_id: "SYS2", external_id: "SYS2")

      data_structure =
        insert(:data_structure,
          system_id: system.id,
          group: "GROUP1",
          name: "NAME1",
          external_id: "EXT1",
          type: "Table"
        )

      dsv = insert(:data_structure_version, data_structure_id: data_structure.id, version: 0)

      field1 =
        insert(:data_field,
          name: "F1",
          type: "T1",
          description: "Field1",
          precision: "P1",
          nullable: false
        )

      field2 =
        insert(:data_field,
          name: "F2",
          type: "T2",
          description: "Will be deleted",
          precision: "P2",
          nullable: true
        )

      field3 =
        insert(:data_field,
          name: "F123123",
          type: "T2",
          description: "Will be also deleted",
          precision: "P2",
          nullable: false
        )

      entries =
        [field1, field2, field3]
        |> Enum.map(fn %{id: id} -> %{data_field_id: id, data_structure_version_id: dsv.id} end)

      Repo.insert_all("versions_fields", entries)

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
        external_id: nil,
        type: "View"
      }

      s3 = %{
        system_id: system.id,
        group: "GROUP2",
        name: "NAME3",
        description: "D2",
        version: 0,
        external_id: nil,
        type: "Report"
      }

      r1 = %{
        system_id: system.id,
        parent_group: "GROUP1",
        parent_external_id: "EXT1",
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2",
        child_external_id: nil
      }

      r2 = %{
        system_id: system.id,
        parent_group: "GROUP1",
        parent_name: "NAME2",
        parent_external_id: nil,
        child_group: "GROUP2",
        child_name: "NAME3",
        child_external_id: nil
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
               Loader.load(structure_records, field_records, relation_records, audit())

      assert %{added: added, removed: removed, modified: modified} = context
      assert added == 4
      assert removed == 2
      assert modified == 1
    end

    test "load/1 allows a fields's metadata to be set and updated" do
      [class1, class2] = [random_string(), random_string()]
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = %{
        system_id: system.id,
        group: random_string("GROUP"),
        name: random_string("NAME"),
        description: random_string("DESC"),
        version: 0,
        external_id: random_string("EXT"),
        type: "Type",
        class: class1
      }

      assert {:ok, _} = Loader.load([structure], [], [], audit())

      assert [%{class: ^class1}] =
               DataStructures.list_data_structures(%{
                 system_id: structure.system_id,
                 external_id: structure.external_id
               })

      assert {:ok, _} = Loader.load([Map.put(structure, :class, class2)], [], [], audit())

      assert [%{class: ^class2}] =
               DataStructures.list_data_structures(%{
                 system_id: structure.system_id,
                 external_id: structure.external_id
               })
    end

    test "load/1 allows a structure's class to be set and updated" do
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = random_structure(system.id)

      1..5
      |> Enum.each(fn _ ->
        class = random_string()
        structure = Map.put(structure, :class, class)
        assert {:ok, _} = Loader.load([structure], [], [], audit())

        assert [%{class: ^class}] =
                 DataStructures.list_data_structures(%{
                   system_id: structure.system_id,
                   external_id: structure.external_id
                 })
      end)
    end
  end

  defp audit do
    %{
      last_change_at: DateTime.truncate(DateTime.utc_now(), :second),
      last_change_by: 0
    }
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

  defp random_string(prefix \\ "") do
    id = :rand.uniform(100_000_000)
    "#{prefix}#{id}"
  end
end
