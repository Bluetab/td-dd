defmodule TdDd.SystemsTest do
  use TdDd.DataCase

  describe "systems" do
    alias TdDd.DataStructures
    alias TdDd.Systems
    alias TdDd.Systems.System

    @valid_attrs %{external_id: "some external_id", name: "some name"}
    @update_attrs %{external_id: "some updated external_id", name: "some updated name"}
    @invalid_attrs %{external_id: nil, name: nil}

    def system_fixture(attrs \\ %{}) do
      {:ok, system} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Systems.create_system()

      system
    end

    test "list_systems/0 returns all systems" do
      system = system_fixture()
      assert Systems.list_systems() == [system]
    end

    test "get_system!/1 returns the system with given id" do
      system = system_fixture()
      assert Systems.get_system!(system.id) == system
    end

    test "create_system/1 with valid data creates a system" do
      assert {:ok, %System{} = system} = Systems.create_system(@valid_attrs)
      assert system.external_id == "some external_id"
      assert system.name == "some name"
    end

    test "create_system/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Systems.create_system(@invalid_attrs)
    end

    test "update_system/2 with valid data updates the system" do
      system = system_fixture()
      assert {:ok, %System{} = system} = Systems.update_system(system, @update_attrs)
      assert system.external_id == "some updated external_id"
      assert system.name == "some updated name"
    end

    test "update_system/2 with invalid data returns error changeset" do
      system = system_fixture()
      assert {:error, %Ecto.Changeset{}} = Systems.update_system(system, @invalid_attrs)
      assert system == Systems.get_system!(system.id)
    end

    test "delete_system/1 deletes the system" do
      system = system_fixture()
      assert {:ok, %System{}} = Systems.delete_system(system)
      assert_raise Ecto.NoResultsError, fn -> Systems.get_system!(system.id) end
    end

    test "get_system_by_external_id/1 gets the system" do
      system = system_fixture()
      assert Systems.get_system_by_external_id(system.external_id) == system
    end

    test "get_system_by_name/1 gets the system" do
      system = system_fixture()
      assert Systems.get_system_by_name(system.name) == system
    end

    test "change_system/1 returns a system changeset" do
      system = system_fixture()
      assert %Ecto.Changeset{} = Systems.change_system(system)
    end

    test "get_system_groups/1 gets the system" do
      system = system_fixture()
      ds1 = insert(:data_structure, system_id: system.id, external_id: "external_id1")
      ds2 = insert(:data_structure, system_id: system.id,  external_id: "external_id2")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 1, group: "group_2")
      assert Systems.get_system_groups(system.external_id) == ["group_2"]
    end

    test "delete_structure_versions/2 deletes structure versions given and external_id and group_name" do
      system = system_fixture()
      ds1 = insert(:data_structure, system_id: system.id, external_id: "external_id1")
      ds2 = insert(:data_structure, system_id: system.id,  external_id: "external_id2")
      ds3 = insert(:data_structure, system_id: system.id,  external_id: "external_id3")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds3.id, version: 0, group: "group_1")
      
      assert {:ok, {2, _}} = Systems.delete_structure_versions(system.external_id, "group_2")
      
      ds1 = 
       ds1 
       |> Map.get(:id)
       |> DataStructures.get_data_structure!() 
       |> DataStructures.with_versions()

      ds2 = 
       ds2 
       |> Map.get(:id)
       |> DataStructures.get_data_structure!()
       |> DataStructures.with_versions()
       

      assert not is_nil(DataStructures.get_latest_version(ds1).deleted_at)
      assert not is_nil(DataStructures.get_latest_version(ds2).deleted_at) 
    end
  end
end
