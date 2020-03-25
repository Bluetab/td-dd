defmodule TdDqWeb.RuleResultControllerTest do
  use TdDqWeb.ConnCase

  import TdDq.Factory
  import TdDqWeb.Authentication, only: :functions

  alias TdDq.Cache.RuleLoader
  alias TdDq.Cache.RuleResultLoader
  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(RuleLoader)
    start_supervised(IndexWorker)
    start_supervised(RuleResultLoader)
    :ok
  end

  setup %{fixture: fixture} do
    rule = insert(:rule, active: true)
    ri = insert(:rule_implementation, implementation_key: "ri135", rule: rule)

    rule_results = %Plug.Upload{path: fixture}
    {:ok, rule_results_file: rule_results, rule_implementation: ri}
  end

  describe "upload rule results" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results_invalid_format.csv"
    test "rule result upload with invalid date", %{
      conn: conn,
      rule_results_file: rule_results_file
    } do
      assert %{"errors" => errors} =
               conn
               |> post(Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
               |> json_response(:unprocessable_entity)

      assert errors == [%{"date" => ["is invalid"], "row_number" => 2}]
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results_result_only.csv"
    test "can load results specifying result", %{
      conn: conn,
      rule_results_file: rule_results_file,
      rule_implementation: rule_implementation
    } do
      conn = post(conn, Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
      assert response(conn, 200)

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_implementation_path(conn, :show, rule_implementation.id))
      results = json_response(conn, 200)["data"]["all_rule_results"]
      assert Enum.map(results, & &1["result"]) == ["4.00", "72.00"]
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "can load results specifying errors and records (result is calculated)", %{
      conn: conn,
      rule_results_file: rule_results_file,
      rule_implementation: rule_implementation
    } do
      conn = post(conn, Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
      assert response(conn, 200)

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_implementation_path(conn, :show, rule_implementation.id))
      results = json_response(conn, 200)["data"]["all_rule_results"]
      assert Enum.map(results, & &1["result"]) == ["0.00", "99.99"]
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results.csv"
    test "uploads rule results with custom params in csv", %{
      conn: conn,
      rule_results_file: rule_results_file,
      rule_implementation: rule_implementation
    } do
      conn = post(conn, Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
      assert response(conn, 200)

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_implementation_path(conn, :show, rule_implementation.id))
      results = json_response(conn, 200)["data"]["all_rule_results"]

      assert results == [
               %{
                 "date" => "2019-08-30T00:00:00Z",
                 "errors" => 4,
                 "implementation_key" => "ri135",
                 "params" => %{"param3" => "5"},
                 "records" => 4,
                 "result" => "0.00"
               },
               %{
                 "date" => "2019-08-29T00:00:00Z",
                 "errors" => 2,
                 "implementation_key" => "ri135",
                 "params" => %{"param1" => "valor", "param2" => "valor2", "param3" => "4"},
                 "records" => 1_000_000,
                 "result" => "99.99"
               }
             ]
    end
  end
end
