defmodule TdDq.RuleResultsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.RuleCache
  alias TdDq.Rules.RuleResults

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup_all do
    start_supervised(TdDq.MockRelationCache)
    start_supervised(TdDq.Cache.RuleLoader)

    on_exit(fn -> Redix.del!(@stream) end)
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
      implementation = insert(:implementation, rule: build(:rule))
      ts = DateTime.utc_now()

      latest =
        insert(:rule_result, implementation: implementation, date: ts)
        |> RuleResults.get_rule_result_thresholds()

      insert(:rule_result, implementation: implementation, date: DateTime.add(ts, -1000))
      insert(:rule_result, implementation: implementation, date: DateTime.add(ts, -2000))

      assert RuleResults.get_latest_rule_result(implementation) <~> latest
    end
  end

  describe "list_rule_results/1" do
    test "retrieves results of non soft deleted rules and implementations" do
      implementation1 = insert(:implementation, deleted_at: DateTime.utc_now())
      implementation2 = insert(:implementation)

      insert(:rule_result, implementation: implementation1)
      result = insert(:rule_result, implementation: implementation2)

      {:ok, %{all: rule_results}} = RuleResults.list_rule_results_paginate()
      assert rule_results ||| [result]
    end

    test "retrieves results with date gt condition" do
      implementation1 = insert(:implementation)
      implementation2 = insert(:implementation)

      insert(:rule_result, implementation: implementation1, date: "2000-01-01T00:00:00")
      result = insert(:rule_result, implementation: implementation2, date: "2000-02-01T11:11:11")

      {:ok, %{all: rule_results}} =
        RuleResults.list_rule_results_paginate(%{"since" => "2000-01-11T11:11:11"})

      assert rule_results ||| [result]
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

    test "updates expecific execution" do
      %{id: implementation_id} = implementation = insert(:implementation)

      %{id: id1} = insert(:execution, implementation_id: implementation_id)

      insert(:execution, implementation_id: implementation_id)

      params = %{
        "date" => "2023-07-17",
        "errors" => 0,
        "records" => 10,
        "execution_id" => id1
      }

      assert {:ok, %{} = multi} = RuleResults.create_rule_result(implementation, params)
      assert %{executions: {1, executions}} = multi
      assert [%{id: ^id1}] = executions
    end

    test "publishes rule_result_created event for an implementation associated to a rule" do
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

    test "publishes rule_result_created event for an implementation not associated to a rule" do
      %{id: domain_id} = CacheHelpers.insert_domain()

      implementation = insert(:ruleless_implementation, domain_id: domain_id)

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

  describe "list_segment_results_by_parent_id/1" do
    test "retrieves only results from specific parent_id " do
      implementation = insert(:implementation)

      insert(:rule_result, implementation: implementation)
      insert(:rule_result, implementation: implementation)
      %{id: parent_id} = insert(:rule_result, implementation: implementation)
      %{id: segment_id_1} = insert(:segment_result, parent_id: parent_id)
      %{id: segment_id_2} = insert(:segment_result, parent_id: parent_id)

      segment_results = RuleResults.list_segment_results_by_parent_id(parent_id)

      assert [
               %{id: ^segment_id_1, parent_id: ^parent_id},
               %{id: ^segment_id_2, parent_id: ^parent_id}
             ] = segment_results

      assert length(segment_results) == 2
    end
  end

  describe "list_segment_results/1" do
    test "retrieves all segments results" do
      insert(:rule_result)
      %{id: parent_id_1} = insert(:rule_result)
      %{id: parent_id_2} = insert(:rule_result)

      %{id: segment_id_1} = insert(:segment_result, parent_id: parent_id_1)
      %{id: segment_id_2} = insert(:segment_result, parent_id: parent_id_2)

      {:ok, %{all: segment_results}} = RuleResults.list_segment_results()

      assert [
               %{id: ^segment_id_1, parent_id: ^parent_id_1},
               %{id: ^segment_id_2, parent_id: ^parent_id_2}
             ] = segment_results

      assert length(segment_results) == 2
    end

    test "retrieves results with date gt condition" do
      %{id: parent_id_1} = insert(:rule_result)
      %{id: parent_id_2} = insert(:rule_result)

      insert(:segment_result, parent_id: parent_id_1, date: "2000-01-01T00:00:00")
      result = insert(:segment_result, parent_id: parent_id_2, date: "2000-02-01T11:11:11")

      {:ok, %{all: segment_results}} =
        RuleResults.list_segment_results(%{"since" => "2000-01-11T11:11:11"})

      assert segment_results ||| [result]
    end

    test "retrieves results paginated by offset ordered by updated_at and segment result id" do
      page_size = 200
      %{id: parent_id} = insert(:rule_result)

      segment_results =
        Enum.map(1..5, fn _ ->
          Enum.map(1..page_size, fn _ -> insert(:segment_result, parent_id: parent_id) end)
        end)

      Enum.reduce(segment_results, 0, fn chunk, offset ->
        {last_chunk_id, _} = get_last_id_updated_at_segments(chunk)

        {:ok, %{all: results, total: total}} =
          RuleResults.list_segment_results(%{
            "cursor" => %{"offset" => offset, "size" => page_size}
          })

        assert 1_000 = total
        assert ^page_size = Enum.count(results)
        {last_segment_id, _} = get_last_id_updated_at_segments(results)
        assert ^last_chunk_id = last_segment_id
        offset + Enum.count(results)
      end)
    end

    test "retrieves ordered segment results paginated by updated_at and id cursor" do
      page_size = 200
      %{id: parent_id} = insert(:rule_result)

      inserted_segment_results =
        [chunk | rest_segments] =
        Enum.map(1..5, fn _ ->
          Enum.map(1..page_size, fn _ -> insert(:segment_result, parent_id: parent_id) end)
        end)

      {_last_chunk_id, last_chunk_updated_at} = get_last_id_updated_at_segments(chunk)

      total_segment_result =
        [chunk | rest_segments]
        |> List.flatten()
        |> Enum.filter(&(NaiveDateTime.to_iso8601(&1.updated_at) >= last_chunk_updated_at))
        |> Enum.count()

      assert {^total_segment_result, _} =
               Enum.reduce(
                 inserted_segment_results,
                 {0, last_chunk_updated_at},
                 fn _chunk, {offset, updated_at} ->
                   {:ok, %{all: segment_results}} =
                     RuleResults.list_segment_results(%{
                       "since" => updated_at,
                       "from" => "updated_at",
                       "cursor" => %{"offset" => offset, "size" => page_size}
                     })

                   Enum.count(segment_results)

                   {offset + Enum.count(segment_results), updated_at}
                 end
               )
    end
  end

  defp get_last_id_updated_at_segments(segment_results) do
    last_segment = List.last(segment_results)
    id = last_segment.id
    updated_at = NaiveDateTime.to_iso8601(last_segment.updated_at)
    {id, updated_at}
  end
end
