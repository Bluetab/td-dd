defmodule TdDqWeb.ExecutionGroupControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  import Mox

  @moduletag sandbox: :shared

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup do
    groups =
      1..5
      |> Enum.map(fn _ -> insert(:execution) end)
      |> Enum.map(fn %{group: group} = execution -> Map.put(group, :executions, [execution]) end)

    [groups: groups]
  end

  describe "GET /api/execution_groups" do
    @tag authentication: [user_name: "not_an_admin", permissions: [:view_quality_rule]]
    test "returns an OK response with the list of execution groups", %{
      conn: conn,
      swagger_schema: schema
    } do
      assert %{"data" => groups} =
               conn
               |> get(Routes.execution_group_path(conn, :index))
               |> validate_resp_schema(schema, "ExecutionGroupsResponse")
               |> json_response(:ok)

      assert length(groups) == 5
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.execution_group_path(conn, :index))
               |> json_response(:forbidden)
    end
  end

  describe "GET /api/execution_groups/:id" do
    @tag authentication: [user_name: "not_an_admin", permissions: [:view_quality_rule]]
    test "returns an OK response with the execution group", %{
      conn: conn,
      swagger_schema: schema,
      groups: groups
    } do
      %{id: id} = Enum.random(groups)

      assert %{"data" => data} =
               conn
               |> get(Routes.execution_group_path(conn, :show, id))
               |> validate_resp_schema(schema, "ExecutionGroupResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "inserted_at" => _, "_embedded" => embedded} = data
      assert %{"executions" => [execution]} = embedded

      assert %{"_embedded" => %{"implementation" => %{"id" => _, "implementation_key" => _}}} =
               execution
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.execution_group_path(conn, :show, 123))
               |> json_response(:forbidden)
    end
  end

  describe "POST /api/execution_groups" do
    @tag authentication: [
           user_name: "not_an_admin",
           permissions: [:execute_quality_rule_implementations, :view_quality_rule]
         ]
    test "returns an OK response with the created execution group", %{
      conn: conn,
      swagger_schema: schema,
      domain: domain
    } do
      %{id: rule_id} = insert(:rule, business_concept_id: "42", domain_id: domain.id)
      %{id: id1} = i1 = insert(:implementation, rule_id: rule_id, domain_id: domain.id)
      %{id: id2} = i2 = insert(:implementation, rule_id: rule_id, domain_id: domain.id)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{from: 0, size: 10_000, query: query}, _ ->
          assert %{
                   bool: %{
                     filter: [
                       %{terms: %{"id" => [_, _]}},
                       %{term: %{"domain_ids" => _}},
                       %{term: %{"executable" => true}},
                       %{term: %{"_confidential" => false}}
                     ],
                     must_not: _deleted_at
                   }
                 } = query

          SearchHelpers.hits_response([i1, i2])
      end)

      filters = %{"id" => [id1, id2]}
      params = %{"filters" => filters, "df_content" => %{"foo" => "bar"}}

      assert %{"data" => data} =
               conn
               |> post(Routes.execution_group_path(conn, :create, params))
               |> validate_resp_schema(schema, "ExecutionGroupResponse")
               |> json_response(:created)

      assert %{"id" => _, "inserted_at" => _, "df_content" => %{"foo" => "bar"}} = data
    end

    @tag authentication: [
           user_name: "not_an_admin",
           permissions: [:execute_quality_rule_implementations, :view_quality_rule]
         ]
    test "returns only allowed implementations to execute", %{
      conn: conn,
      domain: %{id: allowed_domain_id}
    } do
      %{id: id1} = i1 = insert(:implementation, domain_id: allowed_domain_id)
      %{id: id2} = i2 = insert(:implementation, domain_id: allowed_domain_id)
      %{id: forbidden_domain_id} = build(:domain)
      %{id: forbidden_id} = insert(:implementation, domain_id: forbidden_domain_id)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{from: 0, size: 10_000, query: query}, _ ->
          assert %{
                   bool: %{
                     filter: [
                       %{terms: %{"id" => [_, _, _]}},
                       %{term: %{"domain_ids" => ^allowed_domain_id}},
                       %{term: %{"executable" => true}},
                       %{term: %{"_confidential" => false}}
                     ],
                     must_not: _deleted_at
                   }
                 } = query

          SearchHelpers.hits_response([i1, i2])
      end)

      filters = %{"id" => [id1, id2, forbidden_id]}
      params = %{"filters" => filters, "df_content" => %{"foo" => "bar"}}

      assert %{"data" => data} =
               conn
               |> post(Routes.execution_group_path(conn, :create, params))
               |> json_response(:created)

      assert %{"id" => _, "inserted_at" => _, "df_content" => %{"foo" => "bar"}} = data
      assert %{"_embedded" => %{"executions" => executions}} = data

      assert [
               %{"_embedded" => %{"implementation" => %{"id" => ^id1}}},
               %{"_embedded" => %{"implementation" => %{"id" => ^id2}}}
             ] = executions
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have execute permission", %{conn: conn} do
      %{id: id} = insert(:implementation)

      params = %{"implementation_ids" => [id]}

      assert %{"errors" => _} =
               conn
               |> post(Routes.execution_group_path(conn, :index, params))
               |> json_response(:forbidden)
    end
  end
end
