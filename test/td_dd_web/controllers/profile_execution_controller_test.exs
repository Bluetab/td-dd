defmodule TdDdWeb.ExecutionControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @moduletag sandbox: :shared

  setup do
    group = insert(:profile_execution_group)

    executions =
      Enum.map(1..5, fn _ ->
        insert(:profile_execution,
          profile_group: group,
          data_structure: build(:data_structure)
        )
      end)

    [group: group, executions: executions]
  end

  describe "GET /api/profile_executions" do
    @tag authentication: [role: "admin"]
    test "returns an OK response with the list of executions filtered by group", %{
      conn: conn,
      swagger_schema: schema,
      group: group
    } do
      assert %{id: group_id} = group

      assert %{"data" => executions} =
               conn
               |> get(
                 Routes.profile_execution_group_profile_execution_path(conn, :index, group_id)
               )
               |> validate_resp_schema(schema, "ProfileExecutionsResponse")
               |> json_response(:ok)

      assert length(executions) == 5
    end

    @tag authentication: [role: "service"]
    test "returns an OK response with the list of executions", %{
      conn: conn,
      swagger_schema: schema
    } do
      assert %{"data" => executions} =
               conn
               |> get(Routes.profile_execution_path(conn, :index))
               |> validate_resp_schema(schema, "ProfileExecutionsResponse")
               |> json_response(:ok)

      assert length(executions) == 5
    end
  end
end
