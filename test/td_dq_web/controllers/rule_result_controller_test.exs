defmodule TdDqWeb.RuleResultControllerTest do
  use TdDqWeb.ConnCase

  setup_all do
    start_supervised(TdDq.Cache.RuleLoader)
    start_supervised(TdDd.Search.MockIndexWorker)
    :ok
  end

  setup tags do
    case tags[:fixture] do
      nil ->
        :ok

      fixture ->
        rule = insert(:rule, active: true)
        ri = insert(:implementation, implementation_key: "ri135", rule: rule, status: :published)

        rule_results = %Plug.Upload{path: fixture}
        {:ok, rule: rule, rule_results_file: rule_results, implementation: ri}
    end
  end

  describe "GET /api/rule_results" do
    @tag authentication: [role: "service"]
    test "service account can view rule results", %{conn: conn} do
      insert(:rule_result, implementation: build(:implementation))

      assert %{"data" => [_]} =
               conn
               |> get(Routes.rule_result_path(conn, :index))
               |> json_response(:ok)
    end
  end

  describe "delete rule results" do
    @tag authentication: [role: "admin"]
    test "Admin user correctly deletes rule result", %{conn: conn} do
      %{id: id} = insert(:rule_result)

      assert conn
             |> delete(Routes.rule_result_path(conn, :delete, id))
             |> response(:no_content)
    end

    @tag authentication: [role: "admin"]
    test "When delete a rule result with segments, all segments has to be deleted", %{conn: conn} do
      %{id: parent_id} = insert(:rule_result)
      insert(:segment_result, parent_id: parent_id)
      insert(:segment_result, parent_id: parent_id)
      insert(:segment_result, parent_id: parent_id)

      assert %{"data" => [_ | _]} =
               conn
               |> get(Routes.rule_result_segment_result_path(conn, :index, parent_id))
               |> json_response(:ok)

      assert conn
             |> delete(Routes.rule_result_path(conn, :delete, parent_id))
             |> response(:no_content)

      assert %{"data" => []} =
               conn
               |> get(Routes.rule_result_segment_result_path(conn, :index, parent_id))
               |> json_response(:ok)
    end
  end

  describe "POST /api/rule_results" do
    @tag authentication: [role: "admin"]
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "admin can upload rule results", %{
      conn: conn,
      rule_results_file: rule_results_file
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:ok)
    end

    @tag authentication: [role: "user"]
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "non-admin cannot upload rule results", %{
      conn: conn,
      rule_results_file: rule_results_file
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: [:manage_rule_results]]
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "non-admin having upload_rule_results permission can upload rule results", %{
      conn: conn,
      rule_results_file: rule_results_file
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:ok)
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/rule_results/rule_results_invalid_format.csv"
    test "rule result upload with invalid date", %{
      conn: conn,
      rule_results_file: rule_results_file
    } do
      assert %{"errors" => errors, "row" => row} =
               conn
               |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
               |> json_response(:unprocessable_entity)

      assert errors == %{"date" => ["is invalid"]}
      assert row == 2
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/rule_results/rule_results_result_only.csv"
    test "can load results specifying result", %{
      conn: conn,
      rule_results_file: rule_results_file,
      implementation: implementation
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation.id))
               |> json_response(:ok)

      assert %{"results" => results} = data
      assert Enum.map(results, & &1["result"]) == ["4.00"]
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/rule_results/rule_results_only_published_implementations.csv"
    test "can load results specifying result only for published implementations", %{
      conn: conn,
      rule: rule,
      rule_results_file: rule_results_file
    } do
      insert(:implementation,
        implementation_key: "published_imp_key",
        rule: rule,
        status: :published
      )

      insert(:implementation, implementation_key: "draft_imp_key", rule: rule, status: :draft)

      assert %{"errors" => errors, "row" => row} =
               conn
               |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
               |> json_response(:unprocessable_entity)

      assert row == 3

      assert errors == %{
               "implementation" => ["implementation does not exist or is not published"]
             }
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "can load results specifying errors and records (result is calculated)", %{
      conn: conn,
      rule_results_file: rule_results_file,
      implementation: implementation
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation.id))
               |> json_response(:ok)

      assert %{"results" => results} = data
      assert Enum.map(results, & &1["result"]) == ["0.00"]
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/rule_results/rule_results.csv"
    test "uploads rule results with custom params in csv", %{
      conn: conn,
      rule_results_file: rule_results_file,
      implementation: implementation
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation.id))
               |> json_response(:ok)

      assert %{"results" => results} = data
      results = Enum.map(results, &Map.drop(&1, ["id"]))

      assert results == [
               %{
                 "date" => "2019-08-30T00:00:00Z",
                 "errors" => 4,
                 "result" => "123.45",
                 "implementation_id" => implementation.id,
                 "params" => %{"param3" => "5"},
                 "records" => 4,
                 "result_type" => "percentage"
               }
             ]
    end

    @tag authentication: [role: "admin"]
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "updates implementation cache with link after uploading rule results", %{
      conn: conn,
      implementation: %{id: implementation_id} = implementation,
      rule_results_file: rule_results_file
    } do
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

      assert conn
             |> post(Routes.rule_result_path(conn, :create), rule_results: rule_results_file)
             |> response(:ok)

      assert {:ok,
              %{
                execution_result_info: %{
                  date: "2019-08-30 00:00:00Z",
                  errors: 4,
                  records: 4,
                  result_text: "quality_result.under_minimum"
                }
              }} = CacheHelpers.get_implementation(implementation_id)
    end
  end
end
