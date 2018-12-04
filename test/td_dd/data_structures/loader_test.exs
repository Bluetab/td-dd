defmodule TdDd.LoaderTest do
  use TdDd.DataCase

  alias TdDd.Loader
  alias TdDd.Repo

  describe "loader" do
    test "load/1 does something" do
      data_structure = insert(:data_structure, system: "SYS1", group: "GROUP1", name: "NAME1")

      dsv = insert(:data_structure_version, data_structure_id: data_structure.id, version: 0)

      field1 = insert(:data_field, name: "F1", type: "T1", description: "D1", precision: "P1")

      field2 =
        insert(:data_field, id: 99, name: "F2", type: "T2", description: "D2", precision: "P2")

      field3 =
        insert(:data_field,
          id: 991,
          name: "F123123",
          type: "T2",
          description: "Will be deleted",
          precision: "P2"
        )

      entries =
        [field1, field2, field3]
        |> Enum.map(fn %{id: id} -> %{data_field_id: id, data_structure_version_id: dsv.id} end)

      Repo.insert_all("versions_fields", entries)

      s1 = %{system: "SYS1", group: "GROUP1", name: "NAME1", description: "D1"}
      s2 = %{system: "SYS1", group: "GROUP2", name: "NAME2", description: "D2"}
      s3 = %{system: "SYS2", group: "GROUP3", name: "NAME3", description: "D3"}
      s4 = %{system: "SYS2", group: "GROUP3", name: "NAME4", description: "D4", version: "22"}

      r1 = %{
        system: "SYS1",
        parent_group: "GROUP1",
        parent_name: "NAME1",
        child_group: "GROUP2",
        child_name: "NAME2"
      }

      r2 = %{
        system: "SYS2",
        parent_group: "GROUP3",
        parent_name: "NAME3",
        child_group: "GROUP3",
        child_name: "NAME4"
      }

      f1 = %{
        field_name: "F1",
        type: "T1",
        nullable: "false",
        precision: "P1",
        description: "D1"
      }

      f2 = %{
        field_name: "F2",
        type: "NEWTYPE2",
        nullable: "true",
        description: "NEWDES2",
        metadata: %{foo: "bar"}
      }

      f3 = %{
        field_name: "KZTLF",
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

      audit_fields = %{last_change_at: DateTime.utc_now(), last_change_by: 0}
      structure_records = [s1, s2, s3, s4]
      field_records = [f11, f12, f13, f21, f32]
      relation_records = [r1, r2]

      assert {:ok, context} =
               Loader.load(structure_records, field_records, relation_records, audit_fields)

      assert %{added: added, removed: removed, modified: modified} = context
      assert added == 3
      assert removed == 1
      assert modified == 2
    end
  end
end
