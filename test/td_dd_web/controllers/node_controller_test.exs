defmodule TdDdWeb.NodeControllerTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase

  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  @admin_user_name "app-admin"

  setup_all do
    stop_supervised(GraphData)
    start_supervised(GraphData)
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  setup %{conn: conn} = tags do
    GraphData.state(state: setup_state(tags))
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "NodeController" do
    @tag authenticated_user: @admin_user_name
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "index returns the top-level groups and parent nil", %{conn: conn} do
      conn = get(conn, Routes.node_path(conn, :index))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]
      assert %{"external_id" => "foo", "name" => "foo"} = group
    end

    @tag authenticated_user: @admin_user_name
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "show returns a list including the child resources of the specified group", %{conn: conn} do
      conn = get(conn, Routes.node_path(conn, :show, "foo"))

      assert [first, second] = json_response(conn, 200)["data"]

      assert %{"groups" => [group], "parent" => nil} = first
      assert %{"external_id" => "foo", "name" => "foo"} = group

      assert %{"parent" => "foo", "resources" => resources} = second
      assert %{"bar" => _bar, "baz" => _baz} = Enum.group_by(resources, & &1["external_id"])
      assert %{"bar" => _bar, "baz" => _baz} = Enum.group_by(resources, & &1["name"])
      assert %{"foo_type" => [_bar, _baz]} = Enum.group_by(resources, & &1["type"])
    end
  end
end
