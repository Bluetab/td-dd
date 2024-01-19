defmodule TdDqWeb.QualityEventControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdCore.Search.Cluster)
    start_supervised!(TdCore.Search.IndexWorker)

    execution =
      insert(:execution,
        group: build(:execution_group),
        implementation: build(:implementation, rule: build(:rule))
      )

    [execution: execution]
  end

  describe "POST /api/executions/:execution_id/quality_events" do
    @tag authentication: [role: "admin"]
    test "creates an event as an admin user", %{
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

    @tag authentication: [role: "admin"]
    test "creates a failed event as an admin user", %{
      conn: conn,
      swagger_schema: schema,
      execution: execution
    } do
      assert %{id: id} = execution
      message = "foo"
      type = "FAILED"
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
    test "creates an avent as a service user", %{
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
    test "Gets forbidden as a non service or admin user", %{
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
