defmodule TdDdWeb.Schema.ImplementationResultsTest do
  use TdDdWeb.ConnCase

  @implementation_result_query """
  query ImplementationResult($id: ID!) {
    implementationResult(id: $id) {
      id
      date
      details
      params
      errors
      records
      result
      result_type
      has_segments
      has_remediation
    }
  }
  """

  describe "Implementation Results query" do
    @tag authentication: [role: "admin"]
    test "get a result of an implementation", %{conn: conn} do
      %{id: result_id} = insert(:rule_result)
      str_result_id = to_string(result_id)

      assert %{"data" => %{"implementationResult" => implementation_result}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_result_query,
                 "variables" => %{id: result_id}
               })
               |> json_response(:ok)

      assert %{
               "has_remediation" => false,
               "has_segments" => false,
               "id" => ^str_result_id,
               "result" => "50.00"
             } = implementation_result
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule"]
         ]
    test "user with permission can get a result of an implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: implementation_id} = insert(:implementation, domain_id: domain_id)
      %{id: result_id} = insert(:rule_result, implementation_id: implementation_id)

      str_result_id = to_string(result_id)

      assert %{"data" => %{"implementationResult" => implementation_result}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_result_query,
                 "variables" => %{id: result_id}
               })
               |> json_response(:ok)

      assert %{
               "has_remediation" => false,
               "has_segments" => false,
               "id" => ^str_result_id,
               "result" => "50.00"
             } = implementation_result
    end

    @tag authentication: [
           role: "user"
         ]
    test "user without permission cannot get a result of an implementation", %{conn: conn} do
      %{id: result_id} = insert(:rule_result)

      assert %{"errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_result_query,
                 "variables" => %{id: result_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation with has_segmentation boolean", %{conn: conn} do
      %{id: result_id} = insert(:rule_result)
      insert(:segment_result, parent_id: result_id)
      insert(:segment_result, parent_id: result_id)
      str_result_id = to_string(result_id)

      assert %{"data" => %{"implementationResult" => implementation_result}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_result_query,
                 "variables" => %{id: result_id}
               })
               |> json_response(:ok)

      assert %{
               "has_segments" => true,
               "id" => ^str_result_id
             } = implementation_result
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation with has_remediation boolean", %{conn: conn} do
      %{id: result_id} = insert(:rule_result)

      insert(:remediation, rule_result_id: result_id)
      str_result_id = to_string(result_id)

      assert %{"data" => %{"implementationResult" => implementation_result}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_result_query,
                 "variables" => %{id: result_id}
               })
               |> json_response(:ok)

      assert %{
               "has_remediation" => true,
               "has_segments" => false,
               "id" => ^str_result_id
             } = implementation_result
    end
  end
end
