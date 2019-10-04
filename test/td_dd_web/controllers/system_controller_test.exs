defmodule TdDdWeb.SystemControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.PathCache
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
    start_supervised(PathCache)
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
      ds = insert(:data_structure, system_id: system.id, external_id: "struc1")
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      system2 = insert(:system)
      ds = insert(:data_structure, system_id: system2.id, external_id: "struc2")
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      data = json_response(conn, 200)["data"]

      assert length(data) == 1
      [%{"name" => name}] = data
      assert name == "struc1"
    end

    @tag authenticated_user: @admin_user_name
    test "will retrieve only root structures", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, external_id: "parent")
      parent = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      ds = insert(:data_structure, system_id: system.id, external_id: "child")
      child = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      insert(:data_structure_relation, parent_id: parent.id, child_id: child.id)

      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      data = json_response(conn, 200)["data"]

      assert length(data) == 1
      [%{"name" => name}] = data
      assert name == "parent"
    end

    @tag authenticated_user: @admin_user_name
    test "will retrieve only root structures with multiple versions", %{
      conn: conn,
      system: system
    } do
      ds = insert(:data_structure, system_id: system.id, external_id: "parent")
      parent = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      ds = insert(:data_structure, system_id: system.id, external_id: "child")
      child = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      insert(:data_structure_relation, parent_id: parent.id, child_id: child.id)

      insert(:data_structure_version, data_structure_id: ds.id, version: 2)

      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      data = json_response(conn, 200)["data"]

      assert length(data) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "will not break when structure has no versions", %{conn: conn, system: system} do
      insert(:data_structure, system_id: system.id, external_id: "parent")
      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      assert json_response(conn, 200)["data"] == []
    end

    @tag authenticated_no_admin_user: "user"
    test "will filter by permissions for non admin users", %{
      conn: conn,
      user: %{id: user_id},
      system: %{id: system_id} = system
    } do
      structure = create_data_structure_and_permissions(user_id, "no_perms", false, system_id)
      conn = get(conn, Routes.system_data_structure_path(conn, :get_system_structures, system))
      data = json_response(conn, 200)["data"]
      assert not Enum.any?(data, fn %{"id" => ds_id} -> ds_id == structure.id end)
    end
  end

  defp create_data_structure_and_permissions(user_id, role_name, confidential, system_id) do
    domain_name = "domain_name"
    domain_id = 1

    TaxonomyCache.put_domain(%{name: domain_name, id: domain_id})

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role_name
    })

    data_structure =
      insert(
        :data_structure,
        confidential: confidential,
        external_id: "ds",
        ou: domain_name,
        domain_id: domain_id,
        system_id: system_id
      )

    insert(:data_structure_version,
      data_structure_id: data_structure.id,
      name: data_structure.external_id
    )

    data_structure
  end

  defp create_system(_) do
    system = fixture(:system)
    {:ok, system: system}
  end
end
