defmodule TdDdWeb.Schema.ExecutionsTest do
  use TdDdWeb.ConnCase

  alias TdDdWeb.Schema.Types.Custom.Cursor

  @my_execution_groups """
  query MyExecutionGroups($last: Int!, $before: Cursor) {
    me {
      id
      executionGroupsConnection(last: $last, before: $before) {
        totalCount
        pageInfo {
          endCursor
          startCursor
          hasNextPage
          hasPreviousPage
        }
        page {
          id
          statusCounts
          executions {
            id
            implementation {
              id
            }
            qualityEvents {
              id
            }
            result {
              id
            }
            rule {
              id
            }
          }
        }
      }
    }
  }
  """

  @implementation_with_executions """
  query ImplementationExecutions($id: ID!, $last: Int!, $before: Cursor, $filters: [ExecutionFilterInput]) {
    implementation(id: $id) {
      id
      executionFilters {
        field
        values
      }
      executionsConnection(last: $last, before: $before, filters: $filters) {
        totalCount
        pageInfo {
          endCursor
          startCursor
          hasNextPage
          hasPreviousPage
        }
        page {
          id
          latestEvent {
            id
            type
          }
          result {
            id
          }
          rule {
            id
          }
        }
      }
    }
  }
  """

  @implementation_execution_filters """
  query ImplementationExecutions($id: ID!) {
    implementation(id: $id) {
      id
      executionFilters {
        field
        values
      }
    }
  }
  """

  describe "my execution groups query" do
    @tag authentication: [role: "user"]
    test "returns execution groups and associations", %{claims: claims, conn: conn} do
      insert(:execution_group)
      %{id: id} = insert(:execution_group, created_by_id: claims.user_id)

      insert(:execution,
        group_id: id,
        quality_events: [build(:quality_event, type: "SUCCEEDED")],
        result: build(:rule_result),
        rule: build(:rule)
      )

      insert(:execution, group_id: id)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @my_execution_groups,
                 "variables" => %{"last" => 50}
               })
               |> json_response(:ok)

      id = to_string(id)

      assert %{"me" => %{"id" => _, "executionGroupsConnection" => connection}} = data

      assert %{"page" => [execution_group], "totalCount" => 1} = connection

      assert %{"id" => ^id, "executions" => [execution, _], "statusCounts" => status_counts} =
               execution_group

      assert %{
               "id" => _,
               "implementation" => %{"id" => _},
               "qualityEvents" => [%{"id" => _}],
               "result" => %{"id" => _},
               "rule" => %{"id" => _}
             } = execution

      assert status_counts == %{"SUCCEEDED" => 1, "PENDING" => 1}

      refute Map.has_key?(response, "errors")
    end

    @tag authentication: [role: "user"]
    test "paginates and returns pagination info", %{claims: claims, conn: conn} do
      [_, _, g3 | _] =
        Enum.map(1..10, fn _ -> insert(:execution_group, created_by_id: claims.user_id) end)

      variables = %{"last" => 3, "before" => Cursor.encode(g3.id)}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @my_execution_groups, "variables" => variables})
               |> json_response(:ok)

      assert %{"me" => %{"executionGroupsConnection" => connection}} = data

      assert %{"totalCount" => 10, "pageInfo" => page_info, "page" => [_, _]} = connection

      assert %{
               "hasNextPage" => true,
               "hasPreviousPage" => false,
               "startCursor" => _,
               "endCursor" => _
             } = page_info

      refute Map.has_key?(response, "errors")
    end
  end

  describe "implementation execution filters query" do
    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "returns distinct execution status", %{conn: conn, domain: domain} do
      %{id: implementation_id} = insert(:implementation, domain_id: domain.id)

      insert(:execution, implementation_id: implementation_id)

      for status <- ["SUCCEEDED", "FAILED"] do
        insert(:execution,
          implementation_id: implementation_id,
          quality_events: [
            build(:quality_event, type: status, inserted_at: ~U[2000-01-01 02:00:00Z]),
            build(:quality_event, type: "STARTED", inserted_at: ~U[2000-01-01 01:00:00Z])
          ]
        )
      end

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_execution_filters,
                 "variables" => %{"id" => "#{implementation_id}"}
               })
               |> json_response(:ok)

      assert %{
               "implementation" => %{
                 "id" => _,
                 "executionFilters" => filters
               }
             } = data

      assert filters == [
               %{"field" => "status", "values" => ["FAILED", "PENDING", "SUCCEEDED"]}
             ]

      refute Map.has_key?(response, "errors")
    end
  end

  describe "implementation executions query" do
    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "returns implementation executions and associations", %{conn: conn, domain: domain} do
      %{id: implementation_id} = insert(:implementation, domain_id: domain.id)

      for status <- ["FOO", "BAR"] do
        insert(:execution,
          implementation_id: implementation_id,
          quality_events: [build(:quality_event, type: status)],
          result: build(:rule_result),
          rule: build(:rule)
        )
      end

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_executions,
                 "variables" => %{
                   "last" => 50,
                   "id" => "#{implementation_id}",
                   "filters" => [%{"field" => "status", "values" => ["FOO"]}]
                 }
               })
               |> json_response(:ok)

      assert %{
               "implementation" => %{
                 "id" => _,
                 "executionsConnection" => connection
               }
             } = data

      assert %{"page" => [execution], "totalCount" => 1} = connection

      assert %{
               "id" => _,
               "latestEvent" => latest_event,
               "result" => %{"id" => _},
               "rule" => %{"id" => _}
             } = execution

      assert %{"id" => _, "type" => "FOO"} = latest_event

      refute Map.has_key?(response, "errors")
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "paginates and returns pagination info", %{domain: domain, conn: conn} do
      %{id: id} = insert(:implementation, domain_id: domain.id)

      [_, _, i3 | _] = Enum.map(1..10, fn _ -> insert(:execution, implementation_id: id) end)

      variables = %{"id" => "#{id}", "last" => 3, "before" => Cursor.encode(i3.id)}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_executions,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert %{"implementation" => %{"executionsConnection" => connection}} = data

      assert %{"totalCount" => 10, "pageInfo" => page_info, "page" => [_, _]} = connection

      assert %{
               "hasNextPage" => true,
               "hasPreviousPage" => false,
               "startCursor" => _,
               "endCursor" => _
             } = page_info

      refute Map.has_key?(response, "errors")
    end
  end
end
