defmodule TdDdWeb.Schema.TasksTest do
  use TdDdWeb.ConnCase

  alias TdDd.Search.Tasks

  @task_query """
  query Task($id: String!) {
    task(id: $id) {
      id
      index
      count
    }
  }
  """

  @tasks_query """
  query Tasks {
    tasks {
      id
      index
      count
    }
  }
  """

  @moduletag sandbox: :shared

  setup do
    start_supervised!(Tasks)

    Tasks.log_start("test_index")
    Tasks.log_start_stream(10_000)

    [{task_id, _}] =
      Tasks.ets_table()
      |> :ets.tab2list()

    [task_id: "#{task_id}"]
  end

  describe "task query" do
    @tag authentication: [role: "user", permissions: [:foo]]
    test "returns forbidden when queried by user role", %{conn: conn, task_id: task_id} do
      assert %{"errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @task_query,
                 "variables" => %{"id" => task_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{conn: conn, task_id: task_id} do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @task_query,
                 "variables" => %{"id" => task_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"task" => task} = data

      assert %{"id" => task_id, "index" => "test_index", "count" => 10_000} == task
    end

    @tag authentication: [role: "admin"]
    test "returns nil when task_id does not exists", %{conn: conn} do
      task_id = "123"

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @task_query,
                 "variables" => %{"id" => task_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"task" => task} = data

      assert nil == task
    end
  end

  describe "tasks query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @tasks_query})
               |> json_response(:ok)

      assert data == %{"tasks" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{conn: conn, task_id: task_id} do
      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @tasks_query})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"tasks" => tasks} = data

      assert [
               %{
                 "id" => task_id,
                 "index" => "test_index",
                 "count" => 10_000
               }
             ] == tasks
    end
  end
end
