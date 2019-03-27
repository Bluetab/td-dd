defmodule TdDd.LoaderTest do
  use TdDd.DataCase

  alias TdDd.Loader
  alias TdDd.Repo
  alias TdDd.Search.MockIndexWorker
  alias TdPerms.MockDynamicFormCache

  setup_all do
    start_supervised(MockIndexWorker)
    start_supervised(MockDynamicFormCache)
    :ok
  end

  describe "loader" do
    test "load/1 loads changes in data structures, fields and relations" do
      system = insert(:system, external_ref: "SYS1", name: "SYS1")
      insert(:system, external_ref: "SYS2", name: "SYS2")

      data_structure = insert(:data_structure, system: system, group: "GROUP1", name: "NAME1")

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
          id: 99,
          name: "F2",
          type: "T2",
          description: "Field2",
          precision: "P2",
          nullable: true
        )

      field3 =
        insert(:data_field,
          id: 991,
          name: "F123123",
          type: "T2",
          description: "Will be deleted",
          precision: "P2",
          nullable: false
        )

      entries =
        [field1, field2, field3]
        |> Enum.map(fn %{id: id} -> %{data_field_id: id, data_structure_version_id: dsv.id} end)

      Repo.insert_all("versions_fields", entries)

      s1 = %{
        system: "SYS1",
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        version: 0,
        external_id: nil
      }

      s2 = %{
        system: "SYS1",
        group: "GROUP2",
        name: "NAME2",
        description: "D2",
        version: 0,
        external_id: nil
      }

      s3 = %{
        system: "SYS2",
        group: "GROUP3",
        name: "NAME3",
        description: "D3",
        version: 0,
        external_id: nil
      }

      s4 = %{
        system: "SYS2",
        group: "GROUP3",
        name: "NAME4",
        description: "D4",
        version: 22,
        external_id: nil
      }

      s5 = %{
        system: "SYS2",
        group: "GROUP3",
        name: "NAME4",
        description: "D4",
        version: 23,
        external_id: nil
      }

      r1 = %{
        system: "SYS1",
        parent_group: "GROUP1",
        parent_external_id: nil,
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2",
        child_external_id: nil
      }

      r2 = %{
        system: "SYS2",
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

      f11 = s1 |> Map.merge(f1)
      f12 = s1 |> Map.merge(f2)
      f13 = s1 |> Map.merge(f3)
      f21 = s2 |> Map.merge(f1)
      f32 = s3 |> Map.merge(f2)
      f41 = s4 |> Map.merge(f4)
      f51 = s5 |> Map.merge(f4)

      audit_fields = %{last_change_at: DateTime.utc_now(), last_change_by: 0}
      structure_records = [s1, s2, s3, s4, s5]
      field_records = [f11, f12, f13, f21, f32, f41, f51]
      relation_records = [r1, r2]

      assert {:ok, context} =
               Loader.load(structure_records, field_records, relation_records, audit_fields)

      assert %{added: added, removed: removed, modified: modified} = context
      assert added == 6
      assert removed == 2
      assert modified == 1
    end

    test "load/1 with structures containing and external_id" do
      system = insert(:system, external_ref: "SYS1", name: "SYS1")
      insert(:system, external_ref: "SYS2", external_ref: "SYS2")
      data_structure =
        insert(:data_structure,
          system: system,
          group: "GROUP1",
          name: "NAME1",
          external_id: "EXT1"
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
          id: 99,
          name: "F2",
          type: "T2",
          description: "Will be deleted",
          precision: "P2",
          nullable: true
        )

      field3 =
        insert(:data_field,
          id: 991,
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
        system: "SYS1",
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        version: 0,
        external_id: "EXT1"
      }

      s2 = %{
        system: "SYS1",
        group: "GROUP1",
        name: "NAME1",
        description: "D1",
        version: 0,
        external_id: nil
      }

      s3 = %{
        system: "SYS1",
        group: "GROUP2",
        name: "NAME2",
        description: "D2",
        version: 0,
        external_id: nil
      }

      r1 = %{
        system: "SYS1",
        parent_group: "GROUP1",
        parent_external_id: "EXT1",
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2",
        child_external_id: nil
      }

      r2 = %{
        system: "SYS1",
        parent_group: "GROUP1",
        parent_name: "NAME1",
        parent_external_id: nil,
        child_group: "GROUP2",
        child_name: "NAME2",
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

      audit_fields = %{last_change_at: DateTime.utc_now(), last_change_by: 0}
      structure_records = [s1, s2, s3]
      field_records = [f11, f12, f13, f21, f32]
      relation_records = [r1, r2]

      assert {:ok, context} =
               Loader.load(structure_records, field_records, relation_records, audit_fields)

      assert %{added: added, removed: removed, modified: modified} = context
      assert added == 4
      assert removed == 2
      assert modified == 1
    end
  end
end
