defmodule TdDq.RuleResultsTest do
  use TdDq.DataCase

  import Ecto.Query, warn: false

  alias Elasticsearch.Document
  alias TdCache.ConceptCache
  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.RuleCache
  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleResults
  alias TdDq.Search.IndexWorker

  @stream TdCache.Audit.stream()
  @concept_id 987_654_321

  setup_all do
    start_supervised(MockRelationCache)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)

    ConceptCache.put(%{id: @concept_id, domain_id: 42})

    on_exit(fn ->
      ConceptCache.delete(@concept_id)
      Redix.del!(@stream)
    end)
  end

  describe "get_rule_result/1" do
    test "returns result by id" do
      %{implementation_key: key} = insert(:implementation)
      ts = DateTime.utc_now()
      rule_result = insert(:rule_result, implementation_key: key, result: 60, date: ts)
      db_rule_result = RuleResults.get_rule_result(rule_result.id)
      assert rule_result.id == db_rule_result.id
    end
  end

  describe "delete_rule_result/2" do
    test "deletes the rule result" do
      %{implementation_key: key} = insert(:implementation)
      rule_result = insert(:rule_result, implementation_key: key)

      assert {:ok, %{__meta__: meta}} = RuleResults.delete_rule_result(rule_result, nil)
      assert %{state: :deleted} = meta
    end

    test "refreshes the rule cache" do
      %{id: rule_id, name: name} = rule = insert(:rule)
      rule_result = insert(:rule_result)

      assert {:ok, %{__meta__: meta}} = RuleResults.delete_rule_result(rule_result, rule)
      assert {:ok, %{name: ^name}} = RuleCache.get(rule_id)

      on_exit(fn -> RuleCache.delete(rule_id) end)
    end
  end

  describe "get_latest_rule_result/1 " do
    test "returns the latest result of an implementation" do
      %{implementation_key: key} = insert(:implementation)
      ts = DateTime.utc_now()

      latest = insert(:rule_result, implementation_key: key, date: ts)
      insert(:rule_result, implementation_key: key, date: DateTime.add(ts, -1000))
      insert(:rule_result, implementation_key: key, date: DateTime.add(ts, -2000))

      assert RuleResults.get_latest_rule_result(key) == latest
    end
  end

  describe "get_latest_rule_results/1" do
    test "returns a list containing the latest result of an implementation" do
      %{rule: rule, implementation_key: key} = insert(:implementation)
      ts = DateTime.utc_now()

      insert(:rule_result, implementation_key: key, date: DateTime.add(ts, -10))
      latest = insert(:rule_result, implementation_key: key, date: ts)

      assert RuleResults.get_latest_rule_results(rule) == [latest]
    end
  end

  describe "list_rule_results/0" do
    test "retrieves results of non soft deleted rules and implementations" do
      %{implementation_key: key1} = insert(:implementation, deleted_at: DateTime.utc_now())
      %{implementation_key: key2} = insert(:implementation)

      insert(:rule_result, implementation_key: key1)
      result = insert(:rule_result, implementation_key: key2)

      assert RuleResults.list_rule_results() == [result]
    end
  end

  describe "Elasticsearch.Document.encode/1" do
    test "retrieves execution_result_info to be indexed in elastic" do
      impl_key_1 = "impl_key_1"
      impl_key_2 = "impl_key_2"
      goal = 20
      expected_result = 10 |> Decimal.round(2)
      expected_message = "quality_result.under_minimum"
      rule = insert(:rule, df_content: %{}, business_concept_id: nil, goal: goal)
      rule_impl_1 = insert(:implementation, implementation_key: impl_key_1, rule: rule)
      rule_impl_2 = insert(:implementation, implementation_key: impl_key_2, rule: rule)
      now = DateTime.utc_now()

      insert(
        :rule_result,
        implementation_key: rule_impl_1.implementation_key,
        result: 10 |> Decimal.round(2),
        date: DateTime.add(now, -1000)
      )

      insert(
        :rule_result,
        implementation_key: rule_impl_2.implementation_key,
        result: 60 |> Decimal.round(2),
        date: now
      )

      %{execution_result_info: execution_result_info} = Document.encode(rule)

      %{result: result, result_text: result_text} =
        Map.take(execution_result_info, [:result, :result_text])

      assert result == expected_result
      assert expected_message == result_text
    end
  end

  describe "create_rule_result/1" do
    test "creates a rule result with valid result" do
      errors = 2
      records = 1_000_000
      result = abs((records - errors) / records) * 100
      implementation_key = "IMPL4"

      params = %{
        "date" => "2019-01-31-00-00-00",
        "errors" => errors,
        "implementation_key" => implementation_key,
        "records" => records,
        "result" => result
      }

      assert {:ok, %RuleResult{} = rr} = RuleResults.create_rule_result(params)
      assert rr.implementation_key == implementation_key
      assert rr.errors == errors
      assert rr.records == records
      assert rr.result == Decimal.new("99.99")
    end
  end

  describe "bulk_load/1" do
    test "loads rule results and calculates status (number of errors)" do
      rule = build(:rule, result_type: "errors_number", goal: 10, minimum: 20)

      %{implementation_key: key} = insert(:implementation, rule: rule)

      assert {:ok, res} =
               ["1", "15", "30"]
               |> Enum.map(
                 &string_params_for(:rule_result_record, implementation_key: key, errors: &1)
               )
               |> RuleResults.bulk_load()

      assert %{results: results} = res

      assert Enum.group_by(results, & &1.errors, & &1.status) ==
               %{
                 1 => ["success"],
                 15 => ["warn"],
                 30 => ["fail"]
               }
    end

    test "loads rule results and calculates status (percentage)" do
      rule = build(:rule, result_type: "percentage", goal: 100, minimum: 80)

      %{implementation_key: key} = insert(:implementation, rule: rule)

      assert {:ok, res} =
               ["100", "90", "50"]
               |> Enum.map(
                 &string_params_for(:rule_result_record, implementation_key: key, result: &1)
               )
               |> RuleResults.bulk_load()

      assert %{results: results} = res

      assert Enum.group_by(results, &Decimal.to_integer(&1.result), & &1.status) ==
               %{
                 50 => ["fail"],
                 90 => ["warn"],
                 100 => ["success"]
               }
    end

    test "publishes audit events with domain_ids" do
      rule =
        build(:rule,
          result_type: "percentage",
          goal: 100,
          minimum: 80,
          business_concept_id: "#{@concept_id}"
        )

      %{implementation_key: key} = insert(:implementation, rule: rule)
      params = %{"foo" => "bar"}

      assert {:ok, %{audit: [_, event_id, _]}} =
               ["100", "90", "50"]
               |> Enum.map(
                 &string_params_for(:rule_result_record, implementation_key: key, result: &1)
               )
               |> Enum.map(&Map.put(&1, "params", params))
               |> RuleResults.bulk_load()

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
      assert %{event: "rule_result_created", payload: payload} = event

      assert %{"result" => "90.00", "status" => "warn", "params" => ^params, "domain_ids" => _} =
               Jason.decode!(payload)
    end

    test "refreshes rule cache" do
      %{id: rule_id, name: name} = rule = insert(:rule)
      %{implementation_key: key} = insert(:implementation, rule: rule)

      assert {:ok, _} =
               ["100", "90", "50"]
               |> Enum.map(
                 &string_params_for(:rule_result_record, implementation_key: key, result: &1)
               )
               |> RuleResults.bulk_load()

      assert {:ok, %{name: ^name}} = RuleCache.get(rule_id)

      on_exit(fn -> RuleCache.delete(rule_id) end)
    end
  end
end
