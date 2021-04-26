defmodule TdDd.DataStructures.DataStructureTypesTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureTypes

  setup do
    [data_structure_type: insert(:data_structure_type)]
  end

  test "list_data_structure_types/0 returns all data_structure_types", %{
    data_structure_type: data_structure_type
  } do
    assert DataStructureTypes.list_data_structure_types() == [data_structure_type]
  end

  test "get_data_structure_type!/1 returns the data_structure_type with given id", %{
    data_structure_type: %{id: id} = data_structure_type
  } do
    assert DataStructureTypes.get_data_structure_type!(id) == data_structure_type
  end

  describe "create_data_structure_type/1" do
    test "with valid data creates a data_structure_type" do
      %{
        structure_type: structure_type,
        template_id: template_id,
        translation: translation,
        metadata_fields: metadata_fields
      } = params = params_for(:data_structure_type)

      assert {:ok, %DataStructureType{} = data_structure_type} =
               DataStructureTypes.create_data_structure_type(params)

      assert %{
               structure_type: ^structure_type,
               template_id: ^template_id,
               translation: ^translation,
               metadata_fields: ^metadata_fields
             } = data_structure_type
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Changeset{}} =
               DataStructureTypes.create_data_structure_type(%{structure_type: nil})
    end

    test "with an existing structure type returns error changeset", %{
      data_structure_type: %{structure_type: structure_type}
    } do
      params = params_for(:data_structure_type, structure_type: structure_type)

      assert {:error, %Changeset{errors: errors}} =
               DataStructureTypes.create_data_structure_type(params)

      assert {_,
              [constraint: :unique, constraint_name: "data_structure_types_structure_type_index"]} =
               errors[:structure_type]
    end
  end

  describe "update_data_structure_type/2" do
    test "with valid data updates the data_structure_type", %{
      data_structure_type: data_structure_type
    } do
      %{
        structure_type: structure_type,
        template_id: template_id,
        translation: translation,
        metadata_fields: metadata_fields
      } = params = params_for(:data_structure_type)

      assert {:ok, %DataStructureType{} = data_structure_type} =
               DataStructureTypes.update_data_structure_type(data_structure_type, params)

      assert %{
               structure_type: ^structure_type,
               template_id: ^template_id,
               translation: ^translation,
               metadata_fields: ^metadata_fields
             } = data_structure_type
    end

    test "with invalid data returns error changeset", %{data_structure_type: data_structure_type} do
      assert {:error, %Changeset{}} =
               DataStructureTypes.update_data_structure_type(data_structure_type, %{
                 structure_type: nil
               })
    end

    test "with an existing type returns error changeset", %{
      data_structure_type: data_structure_type
    } do
      %{structure_type: existing_structure_type} = insert(:data_structure_type)

      params = params_for(:data_structure_type, structure_type: existing_structure_type)

      assert {:error, %Changeset{errors: errors}} =
               DataStructureTypes.update_data_structure_type(data_structure_type, params)

      assert {_,
              [constraint: :unique, constraint_name: "data_structure_types_structure_type_index"]} =
               errors[:structure_type]
    end
  end

  test "delete_data_structure_type/1 deletes the data_structure_type", %{
    data_structure_type: data_structure_type
  } do
    assert {:ok, %DataStructureType{}} =
             DataStructureTypes.delete_data_structure_type(data_structure_type)

    assert_raise Ecto.NoResultsError, fn ->
      DataStructureTypes.get_data_structure_type!(data_structure_type.id)
    end
  end
end
