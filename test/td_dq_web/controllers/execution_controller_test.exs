defmodule TdDqWeb.ExecutionControllerTest do
  use TdDqWeb.ConnCase

  @moduletag sandbox: :shared

  setup do
    %{id: group_id} = group = insert(:execution_group)

    executions =
      Enum.map(1..5, fn _ ->
        insert(:execution, group_id: group_id, implementation: build(:implementation))
      end)

    [group: group, executions: executions]
  end

  describe "GET /api/executions" do
    @tag authentication: [role: "admin"]
    test "returns an OK response with the list of executions filtered by group", %{
      conn: conn,
      group: group
    } do
      assert %{id: group_id} = group

      assert %{"data" => executions} =
               conn
               |> get(Routes.execution_group_execution_path(conn, :index, group_id))
               |> json_response(:ok)

      assert length(executions) == 5
    end

    @tag authentication: [role: "service"]
    test "returns an OK response with the list of executions", %{
      conn: conn
    } do
      assert %{"data" => executions} =
               conn
               |> get(Routes.execution_path(conn, :index))
               |> json_response(:ok)

      assert length(executions) == 5
    end
  end
end
