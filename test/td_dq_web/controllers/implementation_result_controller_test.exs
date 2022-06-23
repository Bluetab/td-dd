defmodule TdDqWeb.ImplementationResultControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  alias TdDd.Search.MockIndexWorker

  setup_all do
    start_supervised(MockIndexWorker)
    :ok
  end

  setup context do
    %{id: domain_id} =
      case context do
        %{domain: domain} -> domain
        _ -> CacheHelpers.insert_domain()
      end

    %{id: id} = implementation = insert(:implementation, domain_id: domain_id, status: :published)
    execution = insert(:execution, group: build(:execution_group), implementation_id: id)

    [
      execution: execution,
      implementation: implementation,
      domain_id: domain_id
    ]
  end

  describe "POST /api/rule_implementations/:id/results" do
    @tag authentication: [role: "non_admin", permissions: [:manage_rule_results]]
    test "returns 201 Created with the result for a published implementation", %{
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

    @tag authentication: [role: "non_admin", permissions: [:manage_rule_results]]
    test "returns 404 not found when try to create results when implementation is not published ",
         %{
           conn: conn,
           domain_id: domain_id,
           swagger_schema: schema
         } do
      %{id: id, implementation_key: key} =
        _implementation = insert(:implementation, domain_id: domain_id, status: :draft)

      insert(:execution, group: build(:execution_group), implementation_id: id)

      params =
        string_params_for(:implementation_result_record,
          implementation_key: key,
          records: 100,
          errors: 2,
          params: %{"foo" => "bar"}
        )

      conn
      |> post(
        Routes.implementation_implementation_result_path(conn, :create, key),
        rule_result: params
      )
      |> validate_resp_schema(schema, "RuleResultResponse")
      ### conflict
      |> json_response(:not_found)
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_rule_results]]
    test "returns 201 Created with the result with segments on a published implementation", %{
      conn: conn,
      swagger_schema: schema,
      implementation: %{implementation_key: key}
    } do
      params =
        string_params_for(:implementation_result_record,
          implementation_key: key,
          records: 100,
          errors: 2,
          params: %{"foo" => "bar"},
          segments: [
            %{records: 30, errors: 1, params: %{"some" => "thing", "name" => "Country=Spain"}},
            %{records: 90, errors: 0, params: %{"bar" => "baz", "name" => "Country=Japan"}}
          ]
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
               "params" => %{"foo" => "bar"},
               "segments_inserted" => 2
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
    test "returns 404 not found when try to create results on non-existent implementation",
         %{
           conn: conn,
           swagger_schema: schema
         } do
      key = "non-existent implementation key"

      params =
        string_params_for(:implementation_result_record,
          implementation_key: key,
          records: 100,
          errors: 2,
          params: %{"foo" => "bar"}
        )

      conn
      |> post(
        Routes.implementation_implementation_result_path(conn, :create, key),
        rule_result: params
      )
      |> validate_resp_schema(schema, "RuleResultResponse")
      |> json_response(:not_found)
    end

    @tag authentication: [role: "service"]
    test "reindexes rule and implementation after creation", %{conn: conn} do
      MockIndexWorker.clear()

      %{id: rule_id} = rule = insert(:rule)

      %{
        id: implementation_id,
        implementation_key: implementation_key
      } = insert(:implementation, rule: rule, status: :published)

      params = string_params_for(:rule_result_record, implementation_id: implementation_id)

      post(
        conn,
        Routes.implementation_implementation_result_path(conn, :create, implementation_key),
        rule_result: params
      )

      assert MockIndexWorker.calls() == [
               {:reindex_rules, rule_id},
               {:reindex_implementations, implementation_id}
             ]
    end

    @tag authentication: [role: "service"]
    test "updates implementation cache after creation if it has link", %{conn: conn} do
      %{
        id: implementation_id,
        implementation_key: implementation_key
      } = implementation = insert(:implementation, status: :published)

      %{
        "date" => expected_date
      } = params = string_params_for(:rule_result_record, implementation_id: implementation_id)

      CacheHelpers.put_implementation(implementation)

      %{id: concept_id} = CacheHelpers.insert_concept()

      CacheHelpers.insert_link(
        implementation_id,
        "implementation",
        "business_concept",
        concept_id
      )

      {:ok, cache_implementation} = CacheHelpers.get_implementation(implementation_id)
      refute Map.has_key?(cache_implementation, :execution_result_info)

      post(
        conn,
        Routes.implementation_implementation_result_path(conn, :create, implementation_key),
        rule_result: params
      )

      {:ok,
       %{
         execution_result_info: %{
           date: result_date
         }
       }} = CacheHelpers.get_implementation(implementation_id)

      {:ok, expected_date_time} = NaiveDateTime.from_iso8601(expected_date)
      {:ok, result_date_time} = NaiveDateTime.from_iso8601(result_date)
      assert NaiveDateTime.compare(expected_date_time, result_date_time) == :eq
    end
  end
end
