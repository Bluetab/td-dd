defmodule TdDdWeb.DataStructureFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Permissions.MockPermissionResolver
  alias TdDd.Search.MockSearch
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @df_cache Application.get_env(:td_dd, :df_cache)

  setup_all do
    start_supervised MockTdAuthService
    start_supervised MockTdAuditService
    start_supervised MockPermissionResolver
    start_supervised(@df_cache)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @user_name "user"
  describe "index" do
    @tag :admin_authenticated
    test "lists all filters (admin user)", %{conn: conn} do
      conn = get conn, data_structure_filter_path(conn, :index)
      assert json_response(conn, 200)["data"] == MockSearch.get_filters(%{})
    end

    @tag authenticated_no_admin_user: @user_name
    test "lists all filters (non-admin user)", %{conn: conn} do
      conn = get conn, data_structure_filter_path(conn, :index)
      assert json_response(conn, 200)["data"] == %{}
    end
  end

end
