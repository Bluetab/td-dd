defmodule TdDd.DataStructures.DataStructureTypesTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureTypes

  @preload [preload: :metadata_fields]

  setup do
    [data_structure_type: insert(:data_structure_type)]
  end

  describe "list_data_structure_types/1" do
    test "returns all data_structure_types", %{data_structure_type: type} do
      assert [^type] = DataStructureTypes.list_data_structure_types()
    end

    test "enriches with template", %{data_structure_type: %{template_id: template_id}} do
      CacheHelpers.insert_template(id: template_id)
      assert [%{template: %{id: ^template_id}}] = DataStructureTypes.list_data_structure_types()
    end

    test "preloads metadata fields", %{data_structure_type: %{id: id}} do
      assert [%{metadata_fields: []}] = DataStructureTypes.list_data_structure_types(@preload)

      field = insert(:metadata_field, name: "foo", data_structure_type_id: id)

      assert [%{metadata_fields: [^field]}] =
               DataStructureTypes.list_data_structure_types(@preload)

      insert(:metadata_field, name: "bar", data_structure_type_id: id)

      assert [%{metadata_fields: [_foo, _bar]}] =
               DataStructureTypes.list_data_structure_types(@preload)
    end
  end

  describe "get!/2" do
    test "returns the data_structure_type with given id", %{data_structure_type: %{id: id} = type} do
      assert DataStructureTypes.get!(id) == %{type | metadata_fields: []}
    end

    test "enriches with template", %{data_structure_type: %{id: id, template_id: template_id}} do
      CacheHelpers.insert_template(id: template_id)
      assert %{template: %{id: ^template_id}} = DataStructureTypes.get!(id)
    end

    test "preloads metadata fields", %{data_structure_type: %{id: type_id}} do
      assert %{metadata_fields: []} = DataStructureTypes.get!(type_id)

      field = insert(:metadata_field, data_structure_type_id: type_id)
      assert %{metadata_fields: [^field]} = DataStructureTypes.get!(type_id)

      insert(:metadata_field, data_structure_type_id: type_id)
      assert %{metadata_fields: [_bar, _baz]} = DataStructureTypes.get!(type_id)
    end
  end

  describe "get_by/1" do
    test "enriches with template", %{data_structure_type: %{name: name, template_id: template_id}} do
      CacheHelpers.insert_template(id: template_id)
      assert %{template: %{id: ^template_id}} = DataStructureTypes.get_by(name: name)
    end
  end

  describe "get_by/2" do
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
        metadata_views: [metadata_view]
      } = params = params_for(:data_structure_type)

      assert {:ok, %DataStructureType{} = data_structure_type} =
               DataStructureTypes.update_data_structure_type(type, params)

      assert %{
               name: ^name,
               template_id: ^template_id,
               translation: ^translation,
               metadata_views: [view]
             } = data_structure_type

      assert Map.from_struct(view) == metadata_view
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

  describe "metadata_filters/0" do
    test "returns a map with type names as keys and filters as values" do
      %{name: n1} = insert(:data_structure_type, filters: ["foo"])
      %{name: n2} = insert(:data_structure_type, filters: ["bar", "baz"])
      %{name: n3} = insert(:data_structure_type, filters: [])
      %{name: n4} = insert(:data_structure_type, filters: nil)

      filters = DataStructureTypes.metadata_filters()

      assert %{^n1 => ["foo"], ^n2 => ["bar", "baz"]} = filters
      refute Map.has_key?(filters, n3)
      refute Map.has_key?(filters, n4)
    end
  end
end
