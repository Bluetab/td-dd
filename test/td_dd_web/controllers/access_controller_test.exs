defmodule TdDdWeb.LineageEventControllerTest do
  use TdDdWeb.ConnCase

  describe "create" do
    @tag authentication: [role: "admin"]
    test "admin can create accesses", %{conn: conn} do
      assert %{
               "data" => %{
                 "inexistent_external_ids" => [],
                 "inserted_count" => 0,
                 "invalid_changesets" => []
               }
             } =
               conn
               |> post(Routes.access_path(conn, :create), accesses: [])
               |> json_response(:ok)
    end

    @tag authentication: [role: "service"]
    test "service can create accesses", %{conn: conn} do
      assert %{
               "data" => %{
                 "inexistent_external_ids" => [],
                 "inserted_count" => 0,
                 "invalid_changesets" => []
               }
             } =
               conn
               |> post(Routes.access_path(conn, :create), accesses: [])
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "non-admin cannot create accesses", %{
      conn: conn
    } do
      assert conn
             |> post(Routes.access_path(conn, :create), accesses: [])
             |> response(:forbidden)
    end
  end
end
