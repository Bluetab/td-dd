defmodule TdDdWeb.GroupControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Permissions.MockPermissionResolver
  alias TdDd.Search.MockIndexWorker
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(MockIndexWorker)
    :ok
  end

  setup %{conn: conn} do
    system = insert(:system)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), system: system}
  end

  @admin_user_name "app-admin"

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "index", %{conn: conn, swagger_schema: schema, system: system} do
      conn = get(conn, Routes.system_group_path(conn, :index, system.external_id))
      validate_resp_schema(conn, schema, "GroupsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "delete" do
    @tag authenticated_user: @admin_user_name
    test "delete", %{conn: conn, system: system} do
      data_structure = insert(:data_structure, system_id: system.id)

      insert(:data_structure_version,
        data_structure_id: data_structure.id,
        name: data_structure.external_id,
        group: "group_name"
      )

      conn =
        delete(conn, Routes.system_group_path(conn, :delete, system.external_id, "group_name"))

      assert response(conn, 204)
    end
  end
end
