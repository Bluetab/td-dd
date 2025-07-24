defmodule TdDdWeb.UnitControllerTest do
  use Oban.Testing, repo: TdDd.Repo, prefix: Application.get_env(:td_dd, Oban)[:prefix]
  use TdDdWeb.ConnCase

  alias TdDd.TaskSupervisor

  @moduletag sandbox: :shared

  setup_all do
    start_supervised(TdDd.Lineage.Import)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor, max_seconds: 2})
    :ok
  end

  describe "Unit Controller" do
    @tag authentication: [role: "admin"]
    test "GET /api/units returns the list of units", %{conn: conn} do
      Enum.each(1..5, fn _ -> insert(:unit, events: [build(:unit_event)]) end)

      assert %{"data" => units} =
               conn
               |> get(Routes.unit_path(conn, :index))
               |> json_response(:ok)

      assert length(units) == 5
      assert Enum.all?(units, &(&1["status"]["event"] == "EventType"))
    end

    @tag authentication: [role: "admin"]
    test "GET /api/units/:name returns a unit", %{conn: conn} do
      %{name: name} = insert(:unit, events: [build(:unit_event, event: "LoadStarted")])

      assert %{"data" => data} =
               conn
               |> get(Routes.unit_path(conn, :show, name))
               |> json_response(:ok)

      assert %{"name" => ^name, "status" => status} = data
      assert %{"event" => "LoadStarted"} = status
    end

    @tag authentication: [role: "admin"]
    test "POST /api/units creates a unit", %{conn: conn} do
      %{name: name} = build(:unit)

      assert conn
             |> post(Routes.unit_path(conn, :create, name: name))
             |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "POST /api/units returns 422 if params are invalid", %{
      conn: conn
    } do
      assert %{"errors" => errors} =
               conn
               |> post(Routes.unit_path(conn, :create, []))
               |> json_response(:unprocessable_entity)

      assert %{"name" => ["can't be blank"]} = errors
    end

    @tag authentication: [role: "admin"]
    test "DELETE /api/units/:name soft deletes a unit", %{conn: conn} do
      %{name: name, id: id} = insert(:unit)

      assert conn
             |> delete(Routes.unit_path(conn, :delete, name))
             |> response(:accepted)

      assert_enqueued(
        worker: TdDd.Lineage.Units.Workers.DeleteUnit,
        args: %{"unit_id" => id}
      )
    end

    @tag authentication: [role: "admin"]
    test "DELETE /api/units/:name deletes a unit", %{conn: conn} do
      %{name: name, id: id} = insert(:unit)

      assert conn
             |> delete(Routes.unit_path(conn, :delete, name, logical: false))
             |> response(:accepted)

      assert_enqueued(
        worker: TdDd.Lineage.Units.Workers.DeleteUnit,
        args: %{"unit_id" => id, "logical" => "false"}
      )
    end

    @tag authentication: [role: "service"]
    test "PUT /api/units/:name replaces lineage unit metadata", %{
      conn: conn
    } do
      %{name: unit_name} = build(:unit)

      nodes = upload("test/fixtures/lineage/nodes.csv")
      rels = upload("test/fixtures/lineage/rels.csv")

      assert conn
             |> put(Routes.unit_path(conn, :update, unit_name), nodes: nodes, rels: rels)
             |> response(:accepted)

      assert TaskSupervisor.await_completion() in [:normal, :timeout]

      assert %{"data" => data} =
               conn
               |> get(Routes.unit_path(conn, :show, unit_name))
               |> json_response(:ok)

      assert %{"status" => status} = data
      assert %{"event" => "LoadSucceeded", "info" => info} = status
      assert %{"edge_count" => 9, "node_count" => 9, "links_added" => 0} = info
    end

    @tag authentication: [role: "service"]
    test "PUT /api/units/:name replaces lineage unit with metadata", %{
      conn: conn
    } do
      %{name: unit_name} = build(:unit)

      nodes = upload("test/fixtures/lineage/metadata/nodes.csv")
      rels = upload("test/fixtures/lineage/metadata/rels.csv")

      assert conn
             |> put(Routes.unit_path(conn, :update, unit_name), nodes: nodes, rels: rels)
             |> response(:accepted)

      assert TaskSupervisor.await_completion() in [:normal, :timeout]

      assert %{"data" => data} =
               conn
               |> get(Routes.unit_path(conn, :show, unit_name))
               |> json_response(:ok)

      assert %{"status" => status} = data
      assert %{"event" => "LoadSucceeded", "info" => info} = status
      assert %{"edge_count" => 9, "node_count" => 9, "links_added" => 0} = info
    end
  end

  describe "Unit Controller for non-admin users" do
    @tag authentication: [user_name: "non_admin_user"]
    test "GET /api/units returns forbidden", %{conn: conn} do
      assert conn
             |> get(Routes.unit_path(conn, :index))
             |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "GET /api/units/:name returns forbidden", %{conn: conn} do
      assert conn
             |> get(Routes.unit_path(conn, :show, "foo"))
             |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "DELETE /api/units/:name returns forbidden", %{conn: conn} do
      assert conn
             |> get(Routes.unit_path(conn, :delete, "foo"))
             |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "POST /api/units returns forbidden", %{conn: conn} do
      %{name: name} = build(:unit)

      assert conn
             |> post(Routes.unit_path(conn, :create, name: name))
             |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "PUT /api/units/:name returns forbidden", %{conn: conn} do
      nodes = upload("test/fixtures/lineage/nodes.csv")
      rels = upload("test/fixtures/lineage/rels.csv")

      assert conn
             |> put(Routes.unit_path(conn, :update, "foo"), nodes: nodes, rels: rels)
             |> json_response(:forbidden)
    end
  end
end
