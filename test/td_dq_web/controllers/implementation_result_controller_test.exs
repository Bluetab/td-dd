defmodule TdDqWeb.ImplementationResultControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  setup _ do
    %{id: id} = implementation = insert(:implementation)

    execution =
      insert(:execution,
        group: build(:execution_group),
        implementation_id: id
      )

    [
      execution: execution,
      implementation: implementation
    ]
  end

  describe "POST /api/rule_implementations/:id/results" do
    @tag authentication: [role: "service"]
    test "returns 201 Created with the result", %{
      conn: conn,
      swagger_schema: schema,
      implementation: %{implementation_key: key}
    } do
      params =
        string_params_for(:implementation_result_record,
          implementation_key: key,
          records: 100,
          errors: 2,
          params: %{"foo" => "bar"}
        )

      assert %{"data" => data} =
               conn
               |> post(
                 Routes.implementation_implementation_result_path(conn, :create, key),
                 rule_result: params
               )
               |> validate_resp_schema(schema, "RuleResultResponse")
               |> json_response(:created)

      assert %{
               "id" => _,
               "result" => "98.00",
               "params" => %{"foo" => "bar"}
             } = data
    end

    @tag authentication: [user_name: "not_a_connector"]
    test "returns 403 Forbidden if user doesn't have create permission", %{
      conn: conn,
      implementation: %{implementation_key: key}
    } do
      params = string_params_for(:implementation_result_record, records: 100, errors: 2)

      assert %{"errors" => _} =
               conn
               |> post(
                 Routes.implementation_implementation_result_path(conn, :create, key),
                 rule_result: params
               )
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "service"]
    test "returns 404 Not Found if implementation doesn't exist", %{conn: conn} do
      params = string_params_for(:implementation_result_record, records: 100, errors: 2)

      assert %{"errors" => _} =
               conn
               |> post(
                 Routes.implementation_implementation_result_path(conn, :create, "dontexist"),
                 rule_result: params
               )
               |> json_response(:not_found)
    end
  end
end
