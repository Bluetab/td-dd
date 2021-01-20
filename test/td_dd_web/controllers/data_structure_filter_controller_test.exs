defmodule TdDdWeb.DataStructureFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all filters (admin user)", %{conn: conn} do
      conn = get(conn, Routes.data_structure_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "lists all filters (non-admin user)", %{conn: conn} do
      conn = get(conn, Routes.data_structure_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end
  end
end
