defmodule TdDdWeb.Schema.ImplementationResultsTest do
  use TdDdWeb.ConnCase

  alias TdDdWeb.Schema.Types.Custom.Cursor

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
      resultType
      hasSegments
      hasRemediation
    }
  }
  """

  @implementation_with_results """
  query Implementation(
    $id: ID!
    $after: Cursor
    $before: Cursor
    $last: Int
    $first: Int
  ) {
    implementation(id: $id) {
      id
      version
      lastQualityEvent {
        insertedAt
        message
        type
      }
      resultsConnection(
        first: $first
        last: $last
        before: $before
        after: $after
      ) {
        totalCount
        page {
          id
          records
          errors
          result
          date
          implementation {
            id
            version
          }
          __typename
        }
        pageInfo {
          startCursor
          endCursor
          hasNextPage
          hasPreviousPage
          __typename
        }
        __typename
      }
      __typename
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
               "hasRemediation" => false,
               "hasSegments" => false,
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

      %{id: result_id, date: date} = insert(:rule_result, implementation_id: implementation_id)

      str_result_id = to_string(result_id)

      assert %{"data" => %{"implementationResult" => implementation_result}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_result_query,
                 "variables" => %{id: result_id}
               })
               |> json_response(:ok)

      assert %{
               "hasRemediation" => false,
               "hasSegments" => false,
               "date" => result_date,
               "id" => ^str_result_id,
               "result" => "50.00"
             } = implementation_result

      assert result_date == DateTime.to_iso8601(date)
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
               "hasSegments" => true,
               "id" => ^str_result_id
             } = implementation_result
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation with hasRemediation boolean", %{conn: conn} do
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
               "hasRemediation" => true,
               "hasSegments" => false,
               "id" => ^str_result_id
             } = implementation_result
    end
  end

  @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
  test "paginates and returns pagination info", %{domain: domain, conn: conn} do
    %{id: implementation_id_1} = insert(:implementation, domain_id: domain.id, version: 1)

    %{id: implementation_id_2} =
      insert(:implementation,
        domain_id: domain.id,
        version: 2,
        implementation_ref: implementation_id_1
      )

    [_i1r1, _i1r2, %{id: i1r3_id}, %{id: i1r4_id}] =
      Enum.map(1..4, fn _ -> insert(:rule_result, implementation_id: implementation_id_1) end)

    [%{id: i2r1_id}, i2r2, _i2r3, _i2r4] =
      Enum.map(1..4, fn _ -> insert(:rule_result, implementation_id: implementation_id_2) end)

    variables = %{
      "id" => "#{implementation_id_1}",
      "last" => 3,
      "before" => Cursor.encode(i2r2.id)
    }

    assert %{"data" => data} =
             response =
             conn
             |> post("/api/v2", %{
               "query" => @implementation_with_results,
               "variables" => variables
             })
             |> json_response(:ok)

    assert %{"implementation" => %{"resultsConnection" => connection}} = data

    i1r3_id_string = Integer.to_string(i1r3_id)
    i1r4_id_string = Integer.to_string(i1r4_id)
    i2r1_id_string = Integer.to_string(i2r1_id)

    assert %{
             "totalCount" => 8,
             "pageInfo" => page_info,
             "page" =>
               [
                 %{"id" => ^i2r1_id_string},
                 %{"id" => ^i1r4_id_string},
                 %{"id" => ^i1r3_id_string}
               ] = _page
           } = connection

    i2r1_id_base64 = Cursor.encode(i2r1_id)
    i1r3_id_base64 = Cursor.encode(i1r3_id)

    assert %{
             "hasNextPage" => true,
             "hasPreviousPage" => true,
             "startCursor" => ^i1r3_id_base64,
             "endCursor" => ^i2r1_id_base64
           } = page_info

    refute Map.has_key?(response, "errors")
  end
end
