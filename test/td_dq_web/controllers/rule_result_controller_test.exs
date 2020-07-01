defmodule TdDqWeb.RuleResultControllerTest do
  use TdDqWeb.ConnCase

  alias TdDq.Cache.RuleLoader
  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(RuleLoader)
    start_supervised(IndexWorker)
    :ok
  end

  setup %{fixture: fixture} do
    rule = insert(:rule, active: true)
    ri = insert(:implementation, implementation_key: "ri135", rule: rule)

    rule_results = %Plug.Upload{path: fixture}
    {:ok, rule_results_file: rule_results, implementation: ri}
  end

  describe "delete rule results" do
    @tag :admin_authenticated
    @tag fixture: ""
    test "Admin user correctly deletes rule result", %{conn: conn} do
      %{implementation_key: key} = insert(:implementation)
      now = DateTime.utc_now()
      rule_result = insert(:rule_result, implementation_key: key, result: 60, date: now)
      conn = delete(conn, Routes.rule_result_path(conn, :delete, rule_result.id))
      assert response(conn, 204)
    end
  end

  describe "upload rule results" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results_invalid_format.csv"
    test "rule result upload with invalid date", %{
      conn: conn,
      rule_results_file: rule_results_file
    } do
      assert %{"errors" => errors, "row" => row} =
               conn
               |> post(Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
               |> json_response(:unprocessable_entity)

      assert errors == %{"date" => ["is invalid"]}
      assert row == 2
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results_result_only.csv"
    test "can load results specifying result", %{
      conn: conn,
      rule_results_file: rule_results_file,
      implementation: implementation
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation.id))
               |> json_response(:ok)

      assert %{"all_rule_results" => results} = data
      assert Enum.map(results, & &1["result"]) == ["4.00", "72.00"]
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results_errors_records.csv"
    test "can load results specifying errors and records (result is calculated)", %{
      conn: conn,
      rule_results_file: rule_results_file,
      implementation: implementation
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation.id))
               |> json_response(:ok)

      assert %{"all_rule_results" => results} = data
      assert Enum.map(results, & &1["result"]) == ["0.00", "99.99"]
    end

    @tag :admin_authenticated
    @tag fixture: "test/fixtures/rule_results/rule_results.csv"
    test "uploads rule results with custom params in csv", %{
      conn: conn,
      rule_results_file: rule_results_file,
      implementation: implementation
    } do
      assert conn
             |> post(Routes.rule_result_path(conn, :upload), rule_results: rule_results_file)
             |> response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.implementation_path(conn, :show, implementation.id))
               |> json_response(:ok)

      assert %{"all_rule_results" => results} = data
      results = Enum.map(results, &Map.drop(&1, ["id"]))

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
