defmodule TdDd.SystemsTest do
  use TdDd.DataCase

  describe "systems" do
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

    test "get_system_groups_by_external_id/1 gets the system" do
      system = system_fixture()
      ds1 = insert(:data_structure, system_id: system.id, external_id: "external_id1")
      ds2 = insert(:data_structure, system_id: system.id,  external_id: "external_id2")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds1.id, version: 1, group: "group_2")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 0, group: "group_1")
      insert(:data_structure_version, data_structure_id: ds2.id, version: 1, group: "group_2")
      assert Systems.get_system_groups_by_external_id(system.external_id) == ["group_2"]
    end
  end
end
