defmodule TdDd.DataStructures.DataStructureTypesTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureTypes

  setup do
    [data_structure_type: insert(:data_structure_type)]
  end

  describe "list_data_structure_types/0" do
    test "returns all data_structure_types", %{data_structure_type: type} do
      assert [^type] = DataStructureTypes.list_data_structure_types()
    end

    test "enriches with template", %{data_structure_type: %{template_id: template_id}} do
      CacheHelpers.insert_template(id: template_id)
      assert [%{template: %{id: ^template_id}}] = DataStructureTypes.list_data_structure_types()
    end
  end

  describe "get!/1" do
    test "returns the data_structure_type with given id", %{data_structure_type: %{id: id} = type} do
      assert DataStructureTypes.get!(id) == type
    end

    test "enriches with template", %{data_structure_type: %{id: id, template_id: template_id}} do
      CacheHelpers.insert_template(id: template_id)
      assert %{template: %{id: ^template_id}} = DataStructureTypes.get!(id)
    end
  end

  describe "get_by/1" do
    test "enriches with template", %{data_structure_type: %{name: name, template_id: template_id}} do
      CacheHelpers.insert_template(id: template_id)
      assert %{template: %{id: ^template_id}} = DataStructureTypes.get_by(name: name)
    end
  end

  describe "update_data_structure_type/2" do
    test "with valid data updates the data_structure_type", %{data_structure_type: type} do
      %{
        name: name,
        template_id: template_id,
        translation: translation,
        metadata_views: metadata_views
      } = params = params_for(:data_structure_type)

      assert {:ok, %DataStructureType{} = data_structure_type} =
               DataStructureTypes.update_data_structure_type(type, params)

      assert %{
               name: ^name,
               template_id: ^template_id,
               translation: ^translation,
               metadata_views: ^metadata_views
             } = data_structure_type
    end

    test "with invalid data returns error changeset", %{data_structure_type: type} do
      assert {:error, %Changeset{}} =
               DataStructureTypes.update_data_structure_type(type, %{name: nil})
    end

    test "with an existing type returns error changeset", %{
      data_structure_type: type
    } do
      %{name: existing_type} = insert(:data_structure_type)

      params = params_for(:data_structure_type, name: existing_type)

      assert {:error, %Changeset{errors: errors}} =
               DataStructureTypes.update_data_structure_type(type, params)

      assert {_, [constraint: :unique, constraint_name: "data_structure_types_name_index"]} =
               errors[:name]
    end
  end
end
