defmodule TdDdWeb.FileBulkUpdateEventControllerTest do
  use TdDdWeb.ConnCase

  describe "index" do
    @tag authentication: [role: "admin"]
    test "admin can list upload events", %{conn: conn} do
      assert [] =
               conn
               |> get(Routes.file_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "non-admin cannot list upload events without :create_structure_note permission", %{
      conn: conn
    } do
      assert conn
             |> get(Routes.file_bulk_update_event_path(conn, :index))
             |> response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: [:create_structure_note]]
    test "non-admin can list upload events with :create_structure_note permission", %{
      conn: conn
    } do
      assert [] =
               conn
               |> get(Routes.file_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end
  end
end
