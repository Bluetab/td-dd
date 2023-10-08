defmodule TdDd.Lineage.GraphDataIntegrationTest do
  use TdDd.ProcessCase
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State
  alias TdDd.TaskSupervisor

  @moduletag sandbox: :shared
  @mark_completed true

  setup do
    start_supervised(TdDd.Lineage)
    start_supervised(TdDd.Lineage.Import)
    start_supervised({TdDd.Lineage.GraphData, state: %State{notify: notify_callback()}})
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor, max_seconds: 2})
    :ok
  end

  setup :lineage_change

  defp lineage_change(%{conn: conn}) do
    external_id = "Resource1"
    type = "lineage"
    %{name: unit_name} = build(:unit)

    nodes = upload("test/fixtures/lineage/nodes.csv")
    rels = upload("test/fixtures/lineage/rels.csv")

    assert conn
            |> put(Routes.unit_path(conn, :update, unit_name), nodes: nodes, rels: rels)
            |> response(:accepted)

    assert TaskSupervisor.await_completion() in [:normal, :timeout]

    GraphData.refresh()
    assert_receive {:info, {:load_finished, graph_data_state_first_load}}
    %{ts: unit_loaded_1} = graph_data_state_first_load

    assert %{
      "graph_hash" => graph_hash,
      "status" => "JUST_STARTED",
      "task_reference" => task_reference
    } =
      conn
      |> post(Routes.graph_path(conn, :create), type: type, ids: [external_id])
      |> json_response(:accepted)

    TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

    assert %{
      "id" => id,                   # used in front-end redirect
      "ids" => [^external_id],
      "opts" => %{"type" => ^type},
      "groups" => _groups,
      "paths" => _paths,
      "resources" => _resources
    } = conn
    |> post(Routes.graph_path(conn, :create), type: type, ids: [external_id])
    |> json_response(:created)

    assert %{"data" => data} =
              conn
              |> get(Routes.unit_path(conn, :show, unit_name))
              #|> validate_resp_schema(schema, "UnitResponse")
              |> json_response(:ok)

    assert %{"status" => status} = data
    assert %{"event" => "LoadSucceeded", "info" => info} = status
    assert %{"edge_count" => 9, "node_count" => 9, "links_added" => 0} = info

    nodes = upload("test/fixtures/lineage/nodes_add_node.csv")
    rels = upload("test/fixtures/lineage/rels_add_rel.csv")

    assert conn
            |> put(Routes.unit_path(conn, :update, unit_name), nodes: nodes, rels: rels)
            |> response(:accepted)

    assert TaskSupervisor.await_completion() in [:normal, :timeout]

    GraphData.refresh()
    assert_receive {:info, {:load_finished, graph_data_state_second_load}}
    %{ts: unit_loaded_2} = graph_data_state_second_load
    assert :gt = DateTime.compare(unit_loaded_2, unit_loaded_1)

    assert %{"data" => data} =
              conn
              |> get(Routes.unit_path(conn, :show, unit_name))
              #|> validate_resp_schema(schema, "UnitResponse")
              |> json_response(:ok)

    assert %{"status" => status} = data
    assert %{"event" => "LoadSucceeded", "info" => info} = status
    assert %{"edge_count" => 12, "node_count" => 12, "links_added" => 0} = info
    %{id: id, external_id: external_id, type: type, graph_hash: graph_hash}
  end

  @tag authentication: [role: "service"]
  test "creating a graph using the same input parameters across lineage loads updates the graph, keeps the same hash and ID", %{
    conn: conn,
    swagger_schema: schema,
    id: id, external_id: external_id, type: type, graph_hash: graph_hash
  } do

    assert %{
      "graph_hash" => ^graph_hash,
      "status" => "JUST_STARTED",
      "task_reference" => task_reference
    } =
      conn
      |> post(Routes.graph_path(conn, :create), type: type, ids: [external_id])
      |> json_response(:accepted)

    TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

    assert %{
      "id" => ^id,             # used in front-end redirect
      "ids" => [^external_id],
      "opts" =>  %{"type" => ^type},
      "groups" => groups,
      "paths" => paths,
      "resources" => resources
    } = conn
    |> post(Routes.graph_path(conn, :create), type: type, ids: [external_id])
    |> json_response(:created)

    # Check new node and its relations are present.
    assert Enum.find(groups, & &1["id"] == "Group4")
    assert Enum.find(groups, & &1["id"] == "Group4.1")
    assert Enum.find(resources, & &1["id"] == "Resource4")
    assert Enum.find(paths, fn
      %{"v1" => "Resource1", "v2" => "Resource4"} -> true
      _ -> false
    end)
  end

  @tag authentication: [role: "service"]
  test "show graph updates the graph if lineage has changed", %{
    conn: conn,
    id: id, external_id: external_id, type: type, graph_hash: graph_hash
  } do
    assert %{
      "graph_hash" => ^graph_hash,
      "status" => "JUST_STARTED",
      "task_reference" => task_reference
    } =
      conn
      |> get(Routes.graph_path(conn, :show, id))
      |> json_response(:accepted)

    TdDd.Lineage.test_env_task_await(IEx.Helpers.ref(task_reference), @mark_completed)

    assert %{"data" => data} =
      conn
      |> get(Routes.graph_path(conn, :show, id))
      |> json_response(:ok)

    assert %{
      "id" => ^id,                   # used in front-end redirect
      "ids" => [^external_id],
      "opts" => %{"type" => ^type},
      "groups" => groups,
      "paths" => paths,
      "resources" => resources
    } = data

    # Check new node and its relations are present.
    assert Enum.find(groups, & &1["id"] == "Group4")
    assert Enum.find(groups, & &1["id"] == "Group4.1")
    assert Enum.find(resources, & &1["id"] == "Resource4")
    assert Enum.find(paths, fn
      %{"v1" => "Resource1", "v2" => "Resource4"} -> true
      _ -> false
    end)
  end
end
