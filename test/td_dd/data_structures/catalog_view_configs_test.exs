defmodule TdDd.DataStructures.CatalogViewConfigsTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.CatalogViewConfig
  alias TdDd.DataStructures.CatalogViewConfigs

  test "returns all data structure tags" do
    config = insert(:catalog_view_config)
    assert CatalogViewConfigs.list() == [config]
  end

  test "returns the tag with given id" do
    %{id: id} = config = insert(:catalog_view_config)
    assert CatalogViewConfigs.get(id) == config
  end

  describe "CatalogViewConfigs.create/1" do
    test "with valid data creates catalog view config" do
      params = %{"field_type" => "metadata", "field_name" => "some_field_name"}

      assert {:ok, %CatalogViewConfig{} = config} = CatalogViewConfigs.create(params)

      assert %{field_type: "metadata", field_name: "some_field_name"} = config
    end

    test "with invalid data returns error changeset" do
      params = %{"field_type" => "invalid_field_type", "field_name" => "some_field_name"}
      assert {:error, %{valid?: false, errors: errors}} = CatalogViewConfigs.create(params)

      assert {"is invalid", [validation: :inclusion, enum: ["metadata", "note"]]} =
               errors[:field_type]
    end
  end

  describe "CatalogViewConfigs.update/2" do
    test "with valid data updates the catalog view config" do
      config = insert(:catalog_view_config)
      params = %{"field_type" => "metadata", "field_name" => "updated_field_name"}

      assert {:ok, %CatalogViewConfig{} = config} = CatalogViewConfigs.update(config, params)

      assert %{field_type: "metadata", field_name: "updated_field_name"} = config
    end

    test "with invalid data returns error changeset" do
      config = insert(:catalog_view_config)
      params = %{"field_type" => "invalid_field_type", "field_name" => "updated_field_name"}

      assert {:error, %{valid?: false, errors: errors}} =
               CatalogViewConfigs.update(config, params)

      assert {"is invalid", [validation: :inclusion, enum: ["metadata", "note"]]} =
               errors[:field_type]
    end
  end

  describe "CatalogViewConfigs.delete_by_id/1" do
    test "deletes the catalog view config by id" do
      %{id: id} = insert(:catalog_view_config)

      assert {:ok, %CatalogViewConfig{id: ^id}} = CatalogViewConfigs.delete_by_id(id)

      refute Repo.get(CatalogViewConfig, id)
    end

    test "trying to delete a non-existent id returns not_found" do
      assert {:error, :not_found} = CatalogViewConfigs.delete_by_id(123)
    end
  end
end
