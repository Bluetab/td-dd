defmodule TdDd.DataStructures.DataStructuresTypesTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructuresTypes

  describe "data_structure_types" do
    alias TdDd.DataStructures.DataStructureType

    @valid_attrs %{
      structure_type: "some structure_type",
      template_id: 42,
      translation: "some translation",
      metadata_fields: %{}
    }
    @update_attrs %{
      structure_type: "some updated structure_type",
      template_id: 43,
      translation: "some updated translation",
      metadata_fields: %{"values" => "*"}
    }
    @invalid_attrs %{structure_type: nil, template_id: nil, translation: nil, metadata_fields: nil}

    def data_structure_type_fixture(attrs \\ %{}) do
      {:ok, data_structure_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> DataStructuresTypes.create_data_structure_type()

      data_structure_type
    end

    test "list_data_structure_types/0 returns all data_structure_types" do
      data_structure_type = data_structure_type_fixture()
      assert DataStructuresTypes.list_data_structure_types() == [data_structure_type]
    end

    test "get_data_structure_type!/1 returns the data_structure_type with given id" do
      data_structure_type = data_structure_type_fixture()

      assert DataStructuresTypes.get_data_structure_type!(data_structure_type.id) ==
               data_structure_type
    end

    test "create_data_structure_type/1 with valid data creates a data_structure_type" do
      assert {:ok, %DataStructureType{} = data_structure_type} =
               DataStructuresTypes.create_data_structure_type(@valid_attrs)

      assert data_structure_type.structure_type == "some structure_type"
      assert data_structure_type.template_id == 42
      assert data_structure_type.translation == "some translation"
      assert data_structure_type.metadata_fields == %{}
    end

    test "create_data_structure_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               DataStructuresTypes.create_data_structure_type(@invalid_attrs)
    end

    test "update_data_structure_type/2 with valid data updates the data_structure_type" do
      data_structure_type = data_structure_type_fixture()

      assert {:ok, %DataStructureType{} = data_structure_type} =
               DataStructuresTypes.update_data_structure_type(data_structure_type, @update_attrs)

      assert data_structure_type.structure_type == "some updated structure_type"
      assert data_structure_type.template_id == 43
      assert data_structure_type.translation == "some updated translation"
      assert data_structure_type.metadata_fields == %{"values" => "*"}
    end

    test "update_data_structure_type/2 with invalid data returns error changeset" do
      data_structure_type = data_structure_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               DataStructuresTypes.update_data_structure_type(data_structure_type, @invalid_attrs)

      assert data_structure_type ==
               DataStructuresTypes.get_data_structure_type!(data_structure_type.id)
    end

    test "delete_data_structure_type/1 deletes the data_structure_type" do
      data_structure_type = data_structure_type_fixture()

      assert {:ok, %DataStructureType{}} =
               DataStructuresTypes.delete_data_structure_type(data_structure_type)

      assert_raise Ecto.NoResultsError, fn ->
        DataStructuresTypes.get_data_structure_type!(data_structure_type.id)
      end
    end

    test "change_data_structure_type/1 returns a data_structure_type changeset" do
      data_structure_type = data_structure_type_fixture()

      assert %Ecto.Changeset{} =
               DataStructuresTypes.change_data_structure_type(data_structure_type)
    end
  end
end
