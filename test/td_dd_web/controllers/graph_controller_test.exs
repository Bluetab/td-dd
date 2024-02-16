defmodule TdDdWeb.GraphControllerTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase
  use TdDd.DataCase

  alias TdDd.Lineage

  @mark_completed true
  @mark_not_completed false

  setup_all do
    start_supervised(Lineage)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  describe "GraphController" do
    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz", metadata: %{}}]
    test "create new graph returns the task and graph hash, get graph by hash returns the graph drawing",
         %{conn: conn} do
      assert %{
               "graph_hash" => graph_hash,
               "status" => "JUST_STARTED",
               "task_reference" => task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

      assert %{
               "ids" => ids,
               "opts" => opts,
               "groups" => groups,
               "paths" => paths,
               "resources" => resources
             } =
               conn
               |> get(Routes.graph_path(conn, :get_graph_by_hash, graph_hash))
               |> json_response(:ok)

      assert ids == ["bar"]
      assert opts == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = groups
      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz"}] = paths
      assert [%{"id" => "bar"}, %{"id" => "baz"}] = resources
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [
           {"bar", "baz",
            metadata: %{"params" => "bar_metadata", "posible_values" => "baz_metadata"}}
         ]
    test "create new graph with metadata and returns the task and graph hash, get graph by hash returns the graph drawing",
         %{conn: conn, depends: [{_, _, metadata: metadata}]} do
      assert %{
               "graph_hash" => graph_hash,
               "status" => "JUST_STARTED",
               "task_reference" => task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

      assert %{
               "ids" => ids,
               "opts" => opts,
               "groups" => groups,
               "paths" => paths,
               "resources" => resources
             } =
               conn
               |> get(Routes.graph_path(conn, :get_graph_by_hash, graph_hash))
               |> json_response(:ok)

      assert ids == ["bar"]
      assert opts == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = groups

      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz", "metadata" => metadata_result}] =
               paths

      assert [%{"id" => "bar"}, %{"id" => "baz"}] = resources
      assert ^metadata = metadata_result
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz", metadata: %{}}]
    test "create new graph returns the task and graph hash, get graph by hash returns id, show by id returns the graph drawing",
         %{conn: conn} do
      assert %{
               "graph_hash" => graph_hash,
               "status" => "JUST_STARTED",
               "task_reference" => task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

      assert %{"id" => id} =
               conn
               |> get(Routes.graph_path(conn, :get_graph_by_hash, graph_hash))
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.graph_path(conn, :show, id))
               |> json_response(:ok)

      assert data["ids"] == ["bar"]
      assert data["opts"] == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = data["groups"]
      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz", "metadata" => %{}}] = data["paths"]
      assert [%{"id" => "bar"}, %{"id" => "baz"}] = data["resources"]
    end

    @tag authentication: [role: "admin"]
    test "returns not found for non-existent graph",
         %{conn: conn} do
      assert conn
             |> get(Routes.graph_path(conn, :show, 1234))
             |> json_response(:not_found)
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz", metadata: %{}}]
    test "create existing graph returns the graph drawing", %{conn: conn} do
      insert(:unit_event,
        event: "LoadSucceeded",
        inserted_at: ~U[2007-08-31 01:39:00Z],
        unit: build(:unit)
      )

      assert %{
               "graph_hash" => _graph_hash,
               "status" => "JUST_STARTED",
               "task_reference" => task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

      assert %{
               "ids" => ids,
               "opts" => opts,
               "groups" => groups,
               "paths" => paths,
               "resources" => resources
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:created)

      assert ids == ["bar"]
      assert opts == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = groups
      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz", "metadata" => %{}}] = paths
      assert [%{"id" => "bar"}, %{"id" => "baz"}] = resources
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz", metadata: %{"foo" => "bar"}}]
    test "create existing graph returns the graph drawing with metadata", %{conn: conn} do
      insert(:unit_event,
        event: "LoadSucceeded",
        inserted_at: ~U[2007-08-31 01:39:00Z],
        unit: build(:unit)
      )

      assert %{
               "graph_hash" => _graph_hash,
               "status" => "JUST_STARTED",
               "task_reference" => task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

      assert %{
               "ids" => ids,
               "opts" => opts,
               "groups" => groups,
               "paths" => paths,
               "resources" => resources
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:created)

      assert ids == ["bar"]
      assert opts == %{"type" => "impact"}
      assert [%{"id" => "@@ROOT"}, %{"id" => "foo"}] = groups

      assert [%{"path" => _path, "v1" => "bar", "v2" => "baz", "metadata" => %{"foo" => "bar"}}] =
               paths

      assert [%{"id" => "bar"}, %{"id" => "baz"}] = resources
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz", metadata: %{}}]
    test "create graph while a previous create request has been issued returns already_started",
         %{conn: conn} do
      assert %{
               "graph_hash" => _graph_hash,
               "status" => "JUST_STARTED",
               "task_reference" => task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_not_completed)

      assert %{
               "graph_hash" => _graph_hash,
               "status" => "ALREADY_STARTED",
               "task_reference" => _task_reference
             } =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz", metadata: %{"some" => "bar"}}]
    test "csv returns csv content of a graph by id", %{conn: conn} do
      assert %{"graph_hash" => graph_hash, "task_reference" => task_reference} =
               conn
               |> post(Routes.graph_path(conn, :create), type: "impact", ids: ["bar"])
               |> json_response(:accepted)

      TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

      assert %{"id" => id} =
               conn
               |> get(Routes.graph_path(conn, :get_graph_by_hash, graph_hash))
               |> json_response(:ok)

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
