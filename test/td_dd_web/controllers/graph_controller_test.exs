defmodule TdDdWeb.GraphControllerTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase
  use TdDd.DataCase

  alias TdDd.Lineage
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  @admin_user_name "app-admin"

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(Lineage)
    :ok
  end

  describe "GraphController" do
    @tag authenticated_user: @admin_user_name
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "create returns the id, show returns the graph drawing", %{conn: conn} do
      conn = post(conn, Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.graph_path(conn, :show, id))

      assert %{} = data = json_response(conn, 200)["data"]
      assert data["ids"] == ["bar"]
      assert data["opts"] == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = data["groups"]
      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz"}] = data["paths"]
      assert [%{"id" => "bar"}, %{"id" => "baz"}] = data["resources"]
    end

    @tag authenticated_user: @admin_user_name
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "csv returns csv content of a graph by id", %{conn: conn} do
      conn = post(conn, Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = post(conn, Routes.graph_path(conn, :csv), id: id)

      assert conn.resp_body =~
               "source_external_id;source_name;source_class;target_external_id;target_name;target_class;relation_type\r"

      assert conn.resp_body =~ "foo;foo;Group;bar;bar;Resource;CONTAINS\r"
      assert conn.resp_body =~ "foo;foo;Group;baz;baz;Resource;CONTAINS\r"
      assert conn.resp_body =~ "bar;bar;Resource;baz;baz;Resource;DEPENDS\r"
    end
  end
end
