defmodule TdDdWeb.SystemControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.PathCache
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Permissions.MockPermissionResolver
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

  setup %{conn: conn} do
    system = insert(:system)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), system: system}
  end

  @admin_user_name "app-admin"

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all systems", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_system]} =
               conn
               |> get(Routes.system_path(conn, :index))
               |> validate_resp_schema(schema, "SystemsResponse")
               |> json_response(:ok)
    end
  end

  describe "create system" do
    @tag authenticated_user: @admin_user_name
    test "renders system when data is valid", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.system_path(conn, :create), system: @create_attrs)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:created)
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> post(Routes.system_path(conn, :create), system: @invalid_attrs)
               |> json_response(:unprocessable_entity)
    end
  end

  describe "update system" do
    @tag authenticated_user: @admin_user_name
    test "renders system when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      system: %System{id: id} = system
    } do
      assert %{"data" => data} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: @update_attrs)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "external_id" => "some updated external_id",
               "name" => "some updated name",
               "df_content" => nil
             } = data
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, system: system} do
      assert %{"errors" => errors} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: @invalid_attrs)
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "delete system" do
    @tag authenticated_user: @admin_user_name
    test "deletes chosen system", %{conn: conn, system: system} do
      assert conn
             |> delete(Routes.system_path(conn, :delete, system))
             |> response(:no_content)
    end

    @tag authenticated_user: @admin_user_name
    test "returns not_found if system does not exist", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> delete(Routes.system_path(conn, :delete, -1))
               |> json_response(:not_found)
    end
  end

  describe "get system structures" do
    @tag authenticated_user: @admin_user_name
    test "will filter structures by system", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, external_id: "struc1")
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      system2 = insert(:system)
      ds = insert(:data_structure, system_id: system2.id, external_id: "struc2")
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert [%{"name" => "struc1"}] = data
    end

    @tag authenticated_user: @admin_user_name
    test "will retrieve only root structures", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, external_id: "parent")
      parent = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      ds = insert(:data_structure, system_id: system.id, external_id: "child")
      child = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert [%{"name" => "parent"}] = data
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

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_version, data_structure_id: ds.id, version: 2)

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert length(data) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "will not break when structure has no versions", %{conn: conn, system: system} do
      insert(:data_structure, system_id: system.id, external_id: "parent")

      assert %{"data" => []} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)
    end

    @tag authenticated_no_admin_user: "user"
    test "will filter by permissions for non admin users", %{
      conn: conn,
      user: %{id: user_id},
      system: %{id: system_id} = system
    } do
      structure = create_data_structure_and_permissions(user_id, "no_perms", false, system_id)

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert not Enum.any?(data, fn %{"id" => ds_id} -> ds_id == structure.id end)
    end
  end

  defp create_data_structure_and_permissions(user_id, role_name, confidential, system_id) do
    domain_name = "domain_name"
    domain_id = :random.uniform(1_000_000)
    updated_at = DateTime.utc_now()

    TaxonomyCache.put_domain(%{name: domain_name, id: domain_id, updated_at: updated_at})

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
        domain_id: domain_id,
        system_id: system_id
      )

    insert(:data_structure_version,
      data_structure_id: data_structure.id,
      name: data_structure.external_id
    )

    data_structure
  end
end
