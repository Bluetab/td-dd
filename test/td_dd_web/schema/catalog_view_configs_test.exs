defmodule TdDdWeb.Schema.CatalogViewConfigsTest do
  use TdDdWeb.ConnCase

  @catalog_view_config_query """
  query CatalogViewConfig($id: ID!) {
    catalogViewConfig(id: $id) {
      id
      fieldName
      fieldType
    }
  }
  """

  @catalog_view_configs_query """
  query CatalogViewConfigs {
    catalogViewConfigs {
      id
      fieldName
      fieldType
    }
  }
  """

  @create_catalog_view_config """
  mutation CreateCatalogViewConfig(
    $catalogViewConfig: CreateCatalogViewConfigInput!
  ) {
    createCatalogViewConfig(
      catalogViewConfig: $catalogViewConfig) {
        id
        fieldName
        fieldType
    }
  }
  """

  @update_catalog_view_config """
  mutation UpdateCatalogViewConfig(
    $catalogViewConfig: UpdateCatalogViewConfigInput!
  ) {
    updateCatalogViewConfig(
      catalogViewConfig: $catalogViewConfig) {
        id
        fieldName
        fieldType
    }
  }
  """

  @delete_catalog_view_config """
  mutation DeleteCatalogViewConfig($id: ID!) {
    deleteCatalogViewConfig(
      id: $id) {
        id
        fieldName
        fieldType
    }
  }
  """

  defp create_catalog_view_config(_context) do
    [catalog_view_config: insert(:catalog_view_config)]
  end

  describe "catalog view config query" do
    setup :create_catalog_view_config

    @tag authentication: [role: "user"]
    test "returns data when queried by user role", %{
      conn: conn,
      catalog_view_config: %{
        id: config_id,
        field_type: field_type,
        field_name: field_name
      }
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @catalog_view_config_query,
                 "variables" => %{"id" => config_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"catalogViewConfig" => received_config} = data

      assert %{
               "id" => received_config_id,
               "fieldType" => ^field_type,
               "fieldName" => ^field_name
             } = received_config

      assert received_config_id == to_string(config_id)
    end
  end

  describe "catalog view configs query" do
    setup :create_catalog_view_config

    @tag authentication: [role: "user"]
    test "returns events in descending order", %{
      conn: conn,
      catalog_view_config: %{
        id: config_id,
        field_type: field_type,
        field_name: field_name
      }
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @catalog_view_configs_query
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
      assert %{"catalogViewConfigs" => received_configs} = data

      assert [
               %{
                 "id" => received_config_id,
                 "fieldType" => ^field_type,
                 "fieldName" => ^field_name
               }
             ] = received_configs

      assert received_config_id == to_string(config_id)
    end
  end

  describe "createCatalogViewConfig mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      params = string_params_for(:catalog_view_config)

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_catalog_view_config,
                 "variables" => %{"catalogViewConfig" => params}
               })
               |> json_response(:ok)

      assert data == %{"createCatalogViewConfig" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "creates the catalog view config when performed by admin role", %{conn: conn} do
      %{"field_type" => field_type, "field_name" => field_name} =
        params = string_params_for(:catalog_view_config)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @create_catalog_view_config,
                 "variables" => %{"catalogViewConfig" => params}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
      assert %{"createCatalogViewConfig" => received_config} = data

      assert %{
               "id" => _id,
               "fieldType" => ^field_type,
               "fieldName" => ^field_name
             } = received_config
    end

    @tag authentication: [role: "admin"]
    test "catalog view config creation returns an error if field type is not valid", %{conn: conn} do
      params = %{"fieldType" => "invalid_field_type", "fieldName" => "some_field_name"}

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_catalog_view_config,
                 "variables" => %{"catalogViewConfig" => params}
               })
               |> json_response(:ok)

      assert %{"createCatalogViewConfig" => nil} = data

      assert [
               %{
                 "field" => "field_type",
                 "message" => "is invalid"
               }
             ] = errors
    end
  end

  describe "updateCatalogViewConfig mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      params = string_params_for(:catalog_view_config) |> Map.put("id", 123)

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_catalog_view_config,
                 "variables" => %{"catalogViewConfig" => params}
               })
               |> json_response(:ok)

      assert data == %{"updateCatalogViewConfig" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "updates the catalogViewConfig for an admin user", %{conn: conn} do
      %{id: config_id} = insert(:catalog_view_config)

      params = %{
        "id" => config_id,
        "fieldType" => "metadata",
        "fieldName" => "updated_field_name"
      }

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @update_catalog_view_config,
                 "variables" => %{"catalogViewConfig" => params}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
      assert %{"updateCatalogViewConfig" => received_config} = data

      assert %{
               "id" => received_config_id,
               "fieldType" => "metadata",
               "fieldName" => "updated_field_name"
             } = received_config

      assert received_config_id == to_string(config_id)
    end

    @tag authentication: [role: "admin"]
    test "catalog view update returns an error if field type is not valid", %{conn: conn} do
      %{id: config_id} = insert(:catalog_view_config)

      params = %{
        "id" => config_id,
        "fieldType" => "invalid_type",
        "fieldName" => "updated_field_name"
      }

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_catalog_view_config,
                 "variables" => %{"catalogViewConfig" => params}
               })
               |> json_response(:ok)

      assert %{"updateCatalogViewConfig" => nil} = data

      assert [
               %{
                 "field" => "field_type",
                 "message" => "is invalid"
               }
             ] = errors
    end
  end

  describe "deleteCatalogViewConfig mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      %{id: id} = insert(:catalog_view_config)

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_catalog_view_config,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert %{"deleteCatalogViewConfig" => nil} = data
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns not_found for an admin user", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_catalog_view_config,
                 "variables" => %{"id" => 123}
               })
               |> json_response(:ok)

      assert %{"deleteCatalogViewConfig" => nil} = data
      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "deletes the catalog view config for an admin user", %{conn: conn} do
      %{id: id} = insert(:catalog_view_config)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_catalog_view_config,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
      assert %{"deleteCatalogViewConfig" => %{"id" => received_id}} = data
      assert to_string(id) == received_id
    end
  end
end
