defmodule TdDdWeb.DataStructureFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.MockTaxonomyCache
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService
  alias TdPerms.MockDynamicFormCache

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    start_supervised(MockTaxonomyCache)
    start_supervised(MockDynamicFormCache)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all filters (admin user)", %{conn: conn} do
      conn = get(conn, Routes.data_structure_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authenticated_no_admin_user: "user1"
    test "lists all filters (non-admin user)", %{conn: conn} do
      conn = get(conn, Routes.data_structure_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authenticated_no_admin_user: "user2"
    test "search filters should return at least the informed filters", %{
      conn: conn,
      user: %{id: user_id}
    } do
      # role with :view_data_structure permission
      role_name = "watch"
      create_acl(user_id, role_name)
      filters = %{"system.name.raw" => ["SAP", "SAS"], "type.raw" => ["KNA1", "KNB1"]}

      conn =
        post(
          conn,
          Routes.data_structure_filter_path(
            conn,
            :search,
            %{"filters" => filters}
          )
        )

      assert json_response(conn, 200)["data"] == %{
               "system.name.raw" => ["SAP", "SAS"],
               "type.raw" => ["KNA1", "KNB1"],
               "confidential" => [false]
             }
    end
  end

  defp create_acl(user_id, role_name) do
    domain_name = "domain_name"
    domain_id = 1
    MockTaxonomyCache.create_domain(%{name: domain_name, id: domain_id})

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role_name
    })
  end
end
