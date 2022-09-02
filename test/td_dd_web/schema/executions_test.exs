defmodule TdDdWeb.Schema.ExecutionsTest do
  use TdDdWeb.ConnCase

  alias TdDdWeb.Schema.Types.Custom.Cursor

  @query """
  query MyExecutionGroups($last: Int!, $before: String) {
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

  describe "my execution groups query" do
    @tag authentication: [role: "user"]
    test "returns execution groups and associations", %{claims: claims, conn: conn} do
      insert(:execution_group)
      %{id: id} = insert(:execution_group, created_by_id: claims.user_id)

      insert(:execution,
        group_id: id,
        quality_events: [build(:quality_event)],
        result: build(:rule_result),
        rule: build(:rule)
      )

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => %{"last" => 50}})
               |> json_response(:ok)

      id = to_string(id)

      assert %{"me" => %{"id" => _, "executionGroupsConnection" => connection}} = data

      assert %{"page" => [execution_group], "totalCount" => 1} = connection

      assert %{"id" => ^id, "executions" => [execution]} = execution_group

      assert %{
               "id" => _,
               "implementation" => %{"id" => _},
               "qualityEvents" => [%{"id" => _}],
               "result" => %{"id" => _},
               "rule" => %{"id" => _}
             } = execution

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
               |> post("/api/v2", %{"query" => @query, "variables" => variables})
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
end
