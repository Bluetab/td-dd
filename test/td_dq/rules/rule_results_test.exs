defmodule TdDq.RuleResultsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.ConceptCache
  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.RuleCache
  alias TdDq.Rules.RuleResults

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()
  @concept_id 987_654_321

  setup_all do
    start_supervised(TdDq.MockRelationCache)
    start_supervised(TdDd.Search.MockIndexWorker)
    start_supervised(TdDq.Cache.RuleLoader)

    ConceptCache.put(%{id: @concept_id, domain_id: 42})

    on_exit(fn ->
      ConceptCache.delete(@concept_id)
      Redix.del!(@stream)
    end)
  end

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "get_rule_result/1" do
    test "returns result by id" do
      implementation = insert(:implementation)
      ts = DateTime.utc_now()
      rule_result = insert(:rule_result, implementation: implementation, result: 60, date: ts)
      db_rule_result = RuleResults.get_rule_result(rule_result.id)
      assert rule_result.id == db_rule_result.id
    end
  end

  describe "delete_rule_result/1" do
    test "deletes the rule result" do
      implementation = insert(:implementation)
      rule_result = insert(:rule_result, implementation: implementation)

      assert {:ok, %{__meta__: meta}} = RuleResults.delete_rule_result(rule_result)
      assert %{state: :deleted} = meta
    end

    test "refreshes the rule cache" do
      %{rule: %{id: rule_id, name: name}} = implementation = insert(:implementation)
      rule_result = insert(:rule_result, implementation: implementation, rule_id: rule_id)

      assert {:ok, _result} = RuleResults.delete_rule_result(rule_result)
      assert {:ok, %{name: ^name}} = RuleCache.get(rule_id)

      on_exit(fn -> RuleCache.delete(rule_id) end)
    end
  end

  describe "get_latest_rule_result/1 " do
    test "returns the latest result of an implementation" do
      implementation = insert(:implementation)
      ts = DateTime.utc_now()

      latest = insert(:rule_result, implementation: implementation, date: ts)
      insert(:rule_result, implementation: implementation, date: DateTime.add(ts, -1000))
      insert(:rule_result, implementation: implementation, date: DateTime.add(ts, -2000))

      assert RuleResults.get_latest_rule_result(implementation) <~> latest
    end
  end

  describe "list_rule_results/0" do
    test "retrieves results of non soft deleted rules and implementations" do
      implementation1 = insert(:implementation, deleted_at: DateTime.utc_now())
      implementation2 = insert(:implementation)

      insert(:rule_result, implementation: implementation1)
      result = insert(:rule_result, implementation: implementation2)

      assert RuleResults.list_rule_results() <|> [result]
    end
  end

  describe "create_rule_result/1" do
    test "creates a (result_type percentage) rule result with valid result" do
      %{id: implementation_id} = implementation = insert(:implementation)
      errors = 2
      records = 1_000_000
      result = abs((records - errors) / records) * 100

      params = %{
        "date" => "2019-01-31-00-00-00",
        "errors" => errors,
        "records" => records,
        "result" => result,
        "result_type" => "percentage"
      }

      assert {:ok, %{result: rr}} = RuleResults.create_rule_result(implementation, params)
      assert rr.implementation_id == implementation_id
      assert rr.errors == errors
      assert rr.records == records
      assert rr.result == Decimal.new("99.99")
    end

    test "creates a (result_type errors_number) rule result with valid result" do
      rule = insert(:rule)

      %{id: implementation_id} =
        implementation = insert(:implementation, rule: rule, result_type: "errors_number")

      errors = 123
      records = 1000
      result = abs((records - errors) * 100 / records)

      params = %{
        "date" => "2020-08-06-08-28-00",
        "errors" => errors,
        "records" => records,
        "result" => result,
        "result_type" => "errors_number"
      }

      assert {:ok, %{result: rr}} = RuleResults.create_rule_result(implementation, params)
      assert rr.implementation_id == implementation_id
      assert rr.errors == errors
      assert rr.records == records
      assert rr.result == Decimal.new("87.70")
    end

    test "creates a (result_type deviation) rule result with valid result" do
      rule = insert(:rule)

      %{id: implementation_id} =
        implementation = insert(:implementation, rule: rule, result_type: "deviation")

      errors = 210
      records = 1000
      result = abs(errors * 100 / records)

      params = %{
        "date" => "2020-08-06-08-28-00",
        "errors" => errors,
        "records" => records,
        "result" => result,
        "result_type" => "deviation"
      }

      assert {:ok, %{result: rr}} = RuleResults.create_rule_result(implementation, params)
      assert rr.implementation_id == implementation_id
      assert rr.errors == errors
      assert rr.records == records
      assert rr.result == Decimal.new("21.00")
    end

    test "updates related executions" do
      %{id: implementation_id} = implementation = insert(:implementation)

      insert(:execution,
        implementation_id: implementation_id,
        group: build(:execution_group),
        result: build(:rule_result)
      )

      %{id: id2} =
        insert(:execution, implementation_id: implementation_id, group: build(:execution_group))

      params = %{
        "date" => "2020-01-31",
        "errors" => 2,
        "implementation_id" => implementation_id,
        "records" => 5,
        "result_type" => "percentage"
      }

      assert {:ok, %{} = multi} = RuleResults.create_rule_result(implementation, params)
      assert %{executions: {1, executions}} = multi
      assert [%{id: ^id2}] = executions
    end

    test "publishes rule_result_created event" do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: business_concept_id} = CacheHelpers.insert_concept(%{domain_id: domain_id})

      implementation =
        insert(:implementation,
          rule: build(:rule, domain_id: domain_id, business_concept_id: business_concept_id)
        )

      errors = 2
      records = 1_000_000
      result = abs((records - errors) / records) * 100

      params = %{"foo" => "bar"}

      attrs = %{
        "date" => "2019-01-31-00-00-00",
        "errors" => errors,
        "records" => records,
        "result" => result,
        "result_type" => "percentage",
        "params" => params
      }

      assert {:ok, %{audit: event_id}} = RuleResults.create_rule_result(implementation, attrs)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
      assert %{event: "rule_result_created", payload: payload} = event

      string_result = result |> Float.floor(2) |> Float.to_string()
      domain_ids = [domain_id]

      assert %{
               "result" => ^string_result,
               "status" => "success",
               "params" => ^params,
               "domain_ids" => ^domain_ids,
               "result_type" => "percentage"
             } = Jason.decode!(payload)
    end
  end
end
