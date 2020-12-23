defmodule TdDqWeb.ExecutionControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdDq.Permissions.MockPermissionResolver)
    :ok
  end

  setup do
    %{id: group_id} = group = insert(:execution_group)

    executions =
      Enum.map(1..5, fn _ ->
        insert(:execution, group_id: group_id, implementation: build(:implementation))
      end)

    executions
    |> Enum.take_random(2)
    |> Enum.map(fn %{id: execution_id} -> insert(:rule_result, execution_id: execution_id) end)

    [group: group, executions: executions]
  end

  describe "GET /api/executions" do
    @tag :admin_authenticated
    test "returns an OK response with the list of executions", %{
      conn: conn,
      swagger_schema: schema,
      group: group
    } do
      assert %{id: group_id} = group

      assert %{"data" => executions} =
               conn
               |> get(Routes.execution_group_execution_path(conn, :index, group_id))
               |> validate_resp_schema(schema, "ExecutionsResponse")
               |> json_response(:ok)

      assert length(executions) == 5
    end
  end
end
