defmodule TdDdWeb.LineageEventControllerTest do
  use TdDdWeb.ConnCase

  describe "index" do
    @tag authentication: [role: "admin"]
    test "admin can list lineage events", %{conn: conn} do
      assert [] =
               conn
               |> get(Routes.lineage_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "non-admin cannot list lineage events without :view_lineage permission", %{
      conn: conn
    } do
      assert conn
             |> get(Routes.lineage_event_path(conn, :index))
             |> response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: [:view_lineage]]
    test "non-admin can list lineage events with :view_lineage permission", %{
      conn: conn
    } do
      assert [] =
               conn
               |> get(Routes.lineage_event_path(conn, :index))
               |> json_response(:ok)
    end
  end
end
