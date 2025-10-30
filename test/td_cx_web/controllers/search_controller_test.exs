defmodule TdCxWeb.SearchControllerTest do
  use TdCxWeb.ConnCase

  describe "reindex_all/2" do
    @tag authentication: [role: "admin"]
    test "reindexes all jobs for admin", %{conn: conn} do
      conn = get(conn, Routes.search_path(conn, :reindex_all))
      assert response(conn, 202) == ""
    end

    @tag authentication: [role: "service"]
    test "reindexes all jobs for service account", %{conn: conn} do
      conn = get(conn, Routes.search_path(conn, :reindex_all))
      assert response(conn, 202) == ""
    end

    @tag authentication: [role: "user"]
    test "returns forbidden for regular users", %{conn: conn} do
      conn = get(conn, Routes.search_path(conn, :reindex_all))
      assert json_response(conn, 403)
    end
  end
end
