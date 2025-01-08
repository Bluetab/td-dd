defmodule TdDdWeb.ProfileEventControllerTest do
  use TdDdWeb.ConnCase

  @moduletag sandbox: :shared

  setup do
    execution =
      insert(:profile_execution,
        profile_group: build(:profile_execution_group),
        data_structure: build(:data_structure)
      )

    [execution: execution]
  end

  describe "POST /api/profile_executions/:profile_execution_id/profile_events" do
    @tag authentication: [role: "admin"]
    test "creates an event when the user is an admin", %{
      conn: conn,
      execution: execution
    } do
      assert %{id: id} = execution
      message = "foo"
      type = "bar"
      params = %{"message" => message, "type" => type}

      assert %{"data" => %{"message" => ^message, "type" => ^type}} =
               conn
               |> post(Routes.profile_execution_profile_event_path(conn, :create, id),
                 profile_event: params
               )
               |> json_response(:created)
    end

    @tag authentication: [role: "service"]
    test "creates an event when the user is service", %{
      conn: conn,
      execution: execution
    } do
      assert %{id: id} = execution
      message = "foo"
      type = "bar"
      params = %{"message" => message, "type" => type}

      assert %{"data" => %{"message" => ^message, "type" => ^type}} =
               conn
               |> post(Routes.profile_execution_profile_event_path(conn, :create, id),
                 profile_event: params
               )
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
               |> post(Routes.profile_execution_profile_event_path(conn, :create, id),
                 profile_event: params
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
               |> post(Routes.profile_execution_profile_event_path(conn, :create, id),
                 profile_event: params
               )
               |> json_response(:unprocessable_entity)

      assert errors
      assert errors != %{}
    end
  end
end
