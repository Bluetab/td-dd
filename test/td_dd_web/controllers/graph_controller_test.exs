defmodule TdDdWeb.GraphControllerTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase
  use TdDd.DataCase

  alias TdDd.Lineage

  setup_all do
    start_supervised(Lineage)
    :ok
  end

  describe "GraphController" do
    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "create returns the id, show returns the graph drawing", %{conn: conn} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.graph_path(conn, :show, id))
               |> json_response(:ok)

      assert data["ids"] == ["bar"]
      assert data["opts"] == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = data["groups"]
      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz"}] = data["paths"]
      assert [%{"id" => "bar"}, %{"id" => "baz"}] = data["resources"]
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "csv returns csv content of a graph by id", %{conn: conn} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:created)

      assert body =
               conn
               |> post(Routes.graph_path(conn, :csv), id: id)
               |> response(:ok)

      assert body =~
               "source_external_id;source_name;source_class;target_external_id;target_name;target_class;relation_type\r"

      assert body =~ "foo;foo;Group;bar;bar;Resource;CONTAINS\r"
      assert body =~ "foo;foo;Group;baz;baz;Resource;CONTAINS\r"
      assert body =~ "bar;bar;Resource;baz;baz;Resource;DEPENDS\r"
    end
  end
end
