defmodule TdDdWeb.GrantFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all filters (admin user)", %{conn: conn} do
      conn = get(conn, Routes.grant_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "lists all filters (non-admin user)", %{conn: conn} do
      conn = get(conn, Routes.grant_filter_path(conn, :index))
      assert json_response(conn, 200)["data"] == %{}
    end

    @tag authentication: [role: "admin"]
    test "search filters should return at least the informed filters", %{conn: conn} do
      filters = %{
        "data_structure_version.name.raw" => ["ds_a2_prepared_economy", "KNA1", "concepts"]
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_filter_path(conn, :search, %{"filters" => filters}))
               |> json_response(:ok)

      assert data == %{
               "data_structure_version.name.raw" => ["ds_a2_prepared_economy", "KNA1", "concepts"]
             }
    end
  end
end
