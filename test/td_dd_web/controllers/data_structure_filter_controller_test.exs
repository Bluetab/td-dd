defmodule TdDdWeb.DataStructureFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
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
  end
end
