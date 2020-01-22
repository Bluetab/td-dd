defmodule TdDq.RuleResultsTest do
  use TdDq.DataCase

  import Ecto.Query, warn: false
  import TdDq.Factory

  alias Elasticsearch.Document
  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Rules
  alias TdDq.Rules.RuleResult
  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(MockRelationCache)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  describe "rule_result" do
    defp add_to_date_time(datetime, increment) do
      DateTime.from_unix!(DateTime.to_unix(datetime) + increment)
    end

    test "get_latest_rule_result/1 returns last rule_implementation rule result" do
      %{implementation_key: key} = insert(:rule_implementation)
      now = DateTime.utc_now()

      insert(:rule_result, implementation_key: key, result: 10, date: add_to_date_time(now, -1000))

      rule_result = insert(:rule_result, implementation_key: key, result: 60, date: now)

      insert(:rule_result, implementation_key: key, result: 80, date: add_to_date_time(now, -2000))

      assert %{result: result} = Rules.get_latest_rule_result(key)
      assert result == rule_result.result |> Decimal.round(2)
    end

    test "get_latest_rule_results/1 retrives last result of each rule implementation" do
      rule = insert(:rule)
      rule_implementation = insert(:rule_implementation, rule: rule)
      now = DateTime.utc_now()

      insert(
        :rule_result,
        implementation_key: rule_implementation.implementation_key,
        result: 10 |> Decimal.round(2),
        date: add_to_date_time(now, -1000)
      )

      last_rule_result =
        insert(
          :rule_result,
          implementation_key: rule_implementation.implementation_key,
          result: 60 |> Decimal.round(2),
          date: now
        )

      results = Rules.get_latest_rule_results(rule)
      assert results == [last_rule_result]
    end

    test "list_rule_results/1 retrieves rule results linked to a rule with existing bc id having a lower result than the minimum or more errors than goal errors" do
      rule_1 =
        insert(:rule,
          name: "Rule 1",
          business_concept_id: "bc_id_1",
          minimum: 90,
          goal: 100
        )

      rule_2 =
        insert(:rule,
          name: "Rule 2",
          business_concept_id: nil,
          minimum: 70,
          goal: 80
        )

      rule_3 =
        insert(:rule,
          name: "Rule 3",
          business_concept_id: "bc_id_3",
          minimum: 70,
          goal: 85
        )

      rule_4 =
        insert(:rule,
          name: "Rule 4",
          business_concept_id: "bc_id_1",
          minimum: 20,
          goal: 10,
          result_type: "errors_number"
        )

      impl_keys = ["key001", "key002", "key003", "key004"]

      rule_impl_1 =
        insert(:rule_implementation, rule: rule_1, implementation_key: Enum.at(impl_keys, 0))

      rule_impl_2 =
        insert(:rule_implementation, rule: rule_2, implementation_key: Enum.at(impl_keys, 1))

      rule_impl_3 =
        insert(:rule_implementation, rule: rule_3, implementation_key: Enum.at(impl_keys, 2))

      rule_impl_4 =
        insert(:rule_implementation, rule: rule_4, implementation_key: Enum.at(impl_keys, 3))

      rule_result =
        insert(
          :rule_result,
          implementation_key: rule_impl_1.implementation_key,
          result: 55 |> Decimal.round(2)
        )

      rule_result_1 =
        insert(
          :rule_result,
          implementation_key: rule_impl_1.implementation_key,
          result: 92 |> Decimal.round(2)
        )

      rule_result_2 =
        insert(
          :rule_result,
          implementation_key: rule_impl_2.implementation_key,
          result: 75 |> Decimal.round(2)
        )

      rule_result_3 =
        insert(
          :rule_result,
          implementation_key: rule_impl_3.implementation_key,
          result: 75 |> Decimal.round(2)
        )

      rule_result_4 = insert(:rule_result)

      rule_result_5 =
        insert(
          :rule_result,
          implementation_key: rule_impl_4.implementation_key,
          errors: 30
        )

      assert Rules.list_rule_results([
               rule_result.id,
               rule_result_1.id,
               rule_result_2.id,
               rule_result_3.id,
               rule_result_4.id,
               rule_result_5.id
             ]) == [
               %{
                 id: rule_result.id,
                 date: rule_result.date,
                 implementation_key: rule_result.implementation_key,
                 result: rule_result.result,
                 rule_id: rule_1.id,
                 inserted_at: rule_result.inserted_at
               },
               %{
                 id: rule_result_5.id,
                 date: rule_result_5.date,
                 implementation_key: rule_result_5.implementation_key,
                 result: rule_result_5.result |> Decimal.round(2),
                 rule_id: rule_4.id,
                 inserted_at: rule_result_5.inserted_at
               }
             ]
    end

    test "list_rule_results retrieves results of non soft deleted rules and implementations" do
      rule_1 = insert(:rule, name: "Rule 1")
      rule_2 = insert(:rule, name: "Rule 2")

      impl_1 =
        insert(:rule_implementation,
          rule: rule_1,
          implementation_key: "key001",
          deleted_at: DateTime.utc_now()
        )

      impl_2 = insert(:rule_implementation, rule: rule_2, implementation_key: "key002")

      insert(
        :rule_result,
        implementation_key: impl_1.implementation_key,
        result: 55 |> Decimal.round(2)
      )

      result =
        insert(
          :rule_result,
          implementation_key: impl_2.implementation_key,
          result: 92 |> Decimal.round(2)
        )

      assert Rules.list_rule_results() == [result]
    end

    test "encode/1 retrieves execution_result_info to be indexed in elastic" do
      impl_key_1 = "impl_key_1"
      impl_key_2 = "impl_key_2"
      goal = 20
      expected_result = 10 |> Decimal.round(2)
      expected_message = "quality_result.under_minimum"
      rule = insert(:rule, df_content: %{}, business_concept_id: nil, goal: goal)
      rule_impl_1 = insert(:rule_implementation, implementation_key: impl_key_1, rule: rule)
      rule_impl_2 = insert(:rule_implementation, implementation_key: impl_key_2, rule: rule)
      now = DateTime.utc_now()

      insert(
        :rule_result,
        implementation_key: rule_impl_1.implementation_key,
        result: 10 |> Decimal.round(2),
        date: add_to_date_time(now, -1000)
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

    test "create_rule_result/1 creates a rule result with valid result" do
      errors = 2
      records = 1_000_000
      result = calculate_result(records, errors)
      implementation_key = "IMPL4"

      params = %{
        "date" => "2019-01-31-00-00-00",
        "errors" => errors,
        "implementation_key" => implementation_key,
        "records" => records,
        "result" => result
      }

      assert {:ok, %RuleResult{} = rr} = Rules.create_rule_result(params)
      assert rr.implementation_key == implementation_key
      assert rr.errors == errors
      assert rr.records == records
      assert rr.result == round_decimal(result)
    end
  end

  defp calculate_result(0, _errors), do: 0

  defp calculate_result(records, errors) do
    abs((records - errors) / records) * 100
  end

  defp round_decimal(result) do
    Decimal.round(Decimal.from_float(result), 2, :floor)
  end
end
