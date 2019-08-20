defmodule TdDd.LoaderTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
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

      insert(:data_structure_version, data_structure_id: data_structure.id, version: 0)
      insert(:data_structure_version, data_structure_id: ds_2.id, version: 0)

      s1 = %{
        description: "D1",
        external_id: data_structure.external_id,
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
               Loader.load(structure_records, field_records, relation_records, audit())
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

      insert(:data_structure_version, data_structure_id: data_structure.id, version: 0)

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
               Loader.load(structure_records, field_records, relation_records, audit())
    end

    test "load/1 allows a fields's metadata to be set and updated" do
      system = insert(:system, external_id: random_string("EXT"), name: random_string("NAME"))

      structure = random_structure(system.id)
      field = structure |> random_field() |> Map.put(:metadata, %{"foo" => "bar"})

      assert {:ok, %{structures: [%{id: structure_id}]}} =
               Loader.load([structure], [], [], audit())

      1..5
      |> Enum.each(fn _ ->
        foo = random_string("FOO")
        field = Map.put(field, :metadata, %{"foo" => foo})
        assert {:ok, _} = Loader.load([structure], [field], [], audit())

        [%{metadata: metadata}] =
          structure_id
          |> DataStructures.get_data_structure_with_fields!()
          |> Map.get(:data_fields)

        assert metadata["foo"] == foo

        [%{metadata: metadata}] =
          structure_id
          |> DataStructures.get_latest_children()

        assert metadata["foo"] == foo
      end)
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
        child_group: "demo",
        child_name: "xxx",
        parent_external_id: "xxx",
        parent_group: "demo",
        parent_name: "xxx",
        system_id: sys1.id
      }

      assert {:error, :relations, _, _} = Loader.load([structure], [], [relation], audit())
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
