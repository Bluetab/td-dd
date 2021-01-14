defmodule TdDdWeb.GroupControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Search.MockIndexWorker

  setup_all do
    start_supervised(TdDd.Permissions.MockPermissionResolver)
    start_supervised(MockIndexWorker)
    :ok
  end

  setup %{conn: conn} do
    system = insert(:system)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), system: system}
  end

  describe "index" do
    @tag :admin_authenticated
    test "index", %{conn: conn, swagger_schema: schema, system: %{external_id: external_id}} do
      assert %{"data" => []} =
               conn
               |> get(Routes.system_group_path(conn, :index, external_id))
               |> validate_resp_schema(schema, "GroupsResponse")
               |> json_response(:ok)
    end
  end

  describe "delete" do
    @tag :admin_authenticated
    test "delete", %{conn: conn, system: %{id: system_id, external_id: external_id}} do
      insert(:data_structure_version,
        data_structure: build(:data_structure, system_id: system_id),
        group: "group_name"
      )

      assert conn
             |> delete(Routes.system_group_path(conn, :delete, external_id, "group_name"))
             |> response(:no_content)
    end
  end
end
