defmodule TdDdWeb.SystemControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Permissions.MockPermissionResolver
  alias TdDd.Systems
  alias TdDd.Systems.System
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{
    external_id: "some external_id",
    name: "some name"
  }
  @update_attrs %{
    external_id: "some updated external_id",
    name: "some updated name"
  }
  @invalid_attrs %{external_id: nil, name: nil}

  setup_all do
    start_supervised(MockTdAuditService)
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  def fixture(:system) do
    {:ok, system} = Systems.create_system(@create_attrs)
    system
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @admin_user_name "app-admin"

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all systems", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.system_path(conn, :index))
      validate_resp_schema(conn, schema, "SystemsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create system" do
    @tag authenticated_user: @admin_user_name
    test "renders system when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, Routes.system_path(conn, :create), system: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "SystemResponse")

      conn = get(conn, Routes.system_path(conn, :show, id))
      validate_resp_schema(conn, schema, "SystemResponse")

      assert %{
               "id" => id,
               "external_id" => "some external_id",
               "name" => "some name"
             } == json_response(conn, 200)["data"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.system_path(conn, :create), system: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update system" do
    setup [:create_system]

    @tag authenticated_user: @admin_user_name
    test "renders system when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      system: %System{id: id} = system
    } do
      conn = put(conn, Routes.system_path(conn, :update, system), system: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.system_path(conn, :show, id))
      validate_resp_schema(conn, schema, "SystemResponse")

      assert %{
               "id" => id,
               "external_id" => "some updated external_id",
               "name" => "some updated name"
             } == json_response(conn, 200)["data"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, system: system} do
      conn = put(conn, Routes.system_path(conn, :update, system), system: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete system" do
    setup [:create_system]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen system", %{conn: conn, system: system} do
      conn = delete(conn, Routes.system_path(conn, :delete, system))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.system_path(conn, :show, system))
      end)
    end
  end

  describe "get system structures" do
    setup [:create_system]

    @tag authenticated_user: @admin_user_name
    test "will filter structures by system", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, name: "struc1")
      insert(:data_structure_version, data_structure_id: ds.id)

      system2 = insert(:system)
      ds = insert(:data_structure, system_id: system2.id, name: "struc2")
      insert(:data_structure_version, data_structure_id: ds.id)

      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      data = json_response(conn, 200)["data"]

      assert length(data) == 1
      [%{"name" => name}] = data
      assert name == "struc1"
    end

    @tag authenticated_user: @admin_user_name
    test "will retrieve only root structures", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, name: "parent")
      parent = insert(:data_structure_version, data_structure_id: ds.id)

      ds = insert(:data_structure, system_id: system.id, name: "child")
      child = insert(:data_structure_version, data_structure_id: ds.id)

      insert(:data_structure_relation, parent_id: parent.id, child_id: child.id)

      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      data = json_response(conn, 200)["data"]

      assert length(data) == 1
      [%{"name" => name}] = data
      assert name == "parent"
    end
  end

  defp create_system(_) do
    system = fixture(:system)
    {:ok, system: system}
  end
end
