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
        ri = insert(:implementation, implementation_key: "ri135", rule: rule)

        rule_results = %Plug.Upload{path: fixture}
        {:ok, rule_results_file: rule_results, implementation: ri}
    end
  end

  describe "GET /api/rule_results" do
    @tag authentication: [role: "service"]
    test "service account can view rule results", %{conn: conn} do
      %{implementation_key: key} = insert(:implementation)
      insert(:rule_result, implementation_key: key)

      assert %{"data" => [_]} =
               conn
               |> get(Routes.rule_result_path(conn, :index))
               |> json_response(:ok)
    end
  end

  describe "delete rule results" do
    @tag authentication: [role: "admin"]
    @tag fixture: ""
    test "Admin user correctly deletes rule result", %{conn: conn} do
      %{implementation_key: key} = insert(:implementation)
      now = DateTime.utc_now()
      rule_result = insert(:rule_result, implementation_key: key, result: 60, date: now)
      conn = delete(conn, Routes.rule_result_path(conn, :delete, rule_result.id))
      assert response(conn, 204)
    end
  end

  describe "POST /api/rule_results" do
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
      assert Enum.map(results, & &1["result"]) == ["4.00", "72.00"]
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
      assert Enum.map(results, & &1["result"]) == ["0.00", "99.99"]
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
                 "implementation_key" => "ri135",
                 "params" => %{"param3" => "5"},
                 "records" => 4,
                 "result_type" => "percentage",
                 "result" => "0.00",
                 "details" => %{}
               },
               %{
                 "date" => "2019-08-29T00:00:00Z",
                 "errors" => 2,
                 "implementation_key" => "ri135",
                 "params" => %{"param1" => "valor", "param2" => "valor2", "param3" => "4"},
                 "records" => 1_000_000,
                 "result_type" => "percentage",
                 "result" => "99.99",
                 "details" => %{}
               }
             ]
    end
  end
end
