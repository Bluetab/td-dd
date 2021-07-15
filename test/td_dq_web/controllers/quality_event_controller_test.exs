defmodule TdDqWeb.QualityEventControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  @moduletag sandbox: :shared

  setup do
    execution =
      insert(:execution,
        group: build(:execution_group),
        implementation: build(:implementation, rule: build(:rule))
      )

    [execution: execution]
  end

  describe "POST /api/executions/:execution_id/quality_events" do
    @tag authentication: [role: "admin"]
    test "creates an event when the user is an admin", %{
      conn: conn,
      swagger_schema: schema,
      execution: execution
    } do
      assert %{id: id} = execution
      message = "foo"
      type = "bar"
      params = %{"message" => message, "type" => type}

      assert %{"data" => %{"message" => ^message, "type" => ^type}} =
               conn
               |> post(Routes.execution_quality_event_path(conn, :create, id),
                 quality_event: params
               )
               |> validate_resp_schema(schema, "QualityEventResponse")
               |> json_response(:created)
    end

    @tag authentication: [role: "service"]
    test "create an avent when the user is service", %{
      conn: conn,
      swagger_schema: schema,
      execution: execution
    } do
      assert %{id: id} = execution
      message = "foo"
      type = "var"
      params = %{"message" => message, "type" => type}

      assert %{"data" => %{"message" => ^message, "type" => ^type}} =
               conn
               |> post(Routes.execution_quality_event_path(conn, :create, id),
                 quality_event: params
               )
               |> validate_resp_schema(schema, "QualityEventResponse")
               |> json_response(:created)
    end

    @tag authentication: [user_name: "user_without_permission"]
    test "Gets forbidden when user is not service nor admin", %{
      conn: conn,
      execution: execution
    } do
      assert %{id: id} = execution
      message = "foo"
      type = "bar"
      params = %{"message" => message, "type" => type}

      assert %{"errors" => _} =
               conn
               |> post(Routes.execution_quality_event_path(conn, :create, id),
                 quality_event: params
               )
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "service"]
    test "gets error on invalid payload", %{
      conn: conn,
      execution: execution
    } do
      assert %{id: id} = execution
      message = String.duplicate("foo", 334)
      type = "bar"
      params = %{"message" => message, "type" => type}

      assert %{"errors" => errors} =
               conn
               |> post(Routes.execution_quality_event_path(conn, :create, id),
                 quality_event: params
               )
               |> json_response(:unprocessable_entity)

      assert errors
      assert errors != %{}
    end
  end
end
