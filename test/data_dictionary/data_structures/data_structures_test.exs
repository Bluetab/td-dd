defmodule DataDictionary.DataStructuresTest do
  use DataDictionary.DataCase

  alias DataDictionary.DataStructures

  describe "data_structures" do
    alias DataDictionary.DataStructures.DataStructure

    @valid_attrs %{description: "some description", group: "some group", last_change: "2010-04-17 14:00:00.000000Z", modifier: 42, name: "some name", system: "some system"}
    @update_attrs %{description: "some updated description", group: "some updated group", last_change: "2011-05-18 15:01:01.000000Z", modifier: 43, name: "some updated name", system: "some updated system"}
    @invalid_attrs %{description: nil, group: nil, last_change: nil, modifier: nil, name: nil, system: nil}

    def data_structure_fixture(attrs \\ %{}) do
      {:ok, data_structure} =
        attrs
        |> Enum.into(@valid_attrs)
        |> DataStructures.create_data_structure()

      data_structure
    end

    test "list_data_structures/0 returns all data_structures" do
      data_structure = data_structure_fixture()
      assert DataStructures.list_data_structures() == [data_structure]
    end

    test "get_data_structure!/1 returns the data_structure with given id" do
      data_structure = data_structure_fixture()
      assert DataStructures.get_data_structure!(data_structure.id) == data_structure
    end

    test "create_data_structure/1 with valid data creates a data_structure" do
      assert {:ok, %DataStructure{} = data_structure} = DataStructures.create_data_structure(@valid_attrs)
      assert data_structure.description == "some description"
      assert data_structure.group == "some group"
      assert data_structure.last_change == DateTime.from_naive!(~N[2010-04-17 14:00:00.000000Z], "Etc/UTC")
      assert data_structure.modifier == 42
      assert data_structure.name == "some name"
      assert data_structure.system == "some system"
    end

    test "create_data_structure/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_data_structure(@invalid_attrs)
    end

    test "update_data_structure/2 with valid data updates the data_structure" do
      data_structure = data_structure_fixture()
      assert {:ok, data_structure} = DataStructures.update_data_structure(data_structure, @update_attrs)
      assert %DataStructure{} = data_structure
      assert data_structure.description == "some updated description"
      assert data_structure.group == "some updated group"
      assert data_structure.last_change == DateTime.from_naive!(~N[2011-05-18 15:01:01.000000Z], "Etc/UTC")
      assert data_structure.modifier == 43
      assert data_structure.name == "some updated name"
      assert data_structure.system == "some updated system"
    end

    test "update_data_structure/2 with invalid data returns error changeset" do
      data_structure = data_structure_fixture()
      assert {:error, %Ecto.Changeset{}} = DataStructures.update_data_structure(data_structure, @invalid_attrs)
      assert data_structure == DataStructures.get_data_structure!(data_structure.id)
    end

    test "delete_data_structure/1 deletes the data_structure" do
      data_structure = data_structure_fixture()
      assert {:ok, %DataStructure{}} = DataStructures.delete_data_structure(data_structure)
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_structure!(data_structure.id) end
    end

    test "change_data_structure/1 returns a data_structure changeset" do
      data_structure = data_structure_fixture()
      assert %Ecto.Changeset{} = DataStructures.change_data_structure(data_structure)
    end
  end
end
