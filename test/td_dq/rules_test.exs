defmodule TdDq.RulesTest do
  use TdDq.DataCase

  import Ecto.Query, warn: false

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDq.Search.IndexWorker

  @stream TdCache.Audit.stream()

  setup_all do
    start_supervised(MockRelationCache)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    [user: build(:user)]
  end

  setup do
    on_exit(fn -> Redix.del!(@stream) end)
    :ok
  end

  describe "list_rules/0" do
    test "returns all rules" do
      rule = insert(:rule)
      assert Rules.list_rules() == [rule]
    end
  end

  describe "get_rule/1" do
    test "returns the rule with given id" do
      rule = insert(:rule)
      assert Rules.get_rule!(rule.id) == rule
    end
  end

  describe "create_rule/2" do
    test "creates a rule with valid data", %{user: user} do
      params = string_params_for(:rule)
      assert {:ok, %{rule: rule}} = Rules.create_rule(params, user)
    end

    test "publishes an audit event", %{user: user} do
      params = string_params_for(:rule)
      assert {:ok, %{audit: event_id}} = Rules.create_rule(params, user)
      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end

    test "returns error and changeset if changeset is invalid", %{user: user} do
      params = Map.from_struct(build(:rule, name: nil))
      assert {:error, :rule, %Ecto.Changeset{}, _} = Rules.create_rule(params, user)
    end
  end

  describe "update_rule/3" do
    test "updates rule if changes are valid", %{user: user} do
      rule = insert(:rule)
      params = %{"name" => "New name", "description" => %{"document" => "New description"}}
      assert {:ok, %{rule: rule}} = Rules.update_rule(rule, params, user)
    end

    test "publishes an audit event", %{user: user} do
      rule = insert(:rule)
      params = %{"name" => "New name"}
      assert {:ok, %{audit: event_id}} = Rules.update_rule(rule, params, user)
      assert {:ok, [%{id: ^event_id}]} = Stream.read(:redix, @stream, transform: true)
    end

    test "returns error and changeset if changeset is invalid", %{user: user} do
      rule = insert(:rule)
      params = %{name: nil}
      assert {:error, :rule, %Ecto.Changeset{}, _} = Rules.update_rule(rule, params, user)
    end
  end

  describe "rule" do
    test "delete_rule/1 deletes the rule", %{user: user} do
      rule = insert(:rule)
      assert {:ok, %{rule: rule}} = Rules.delete_rule(rule, user)
      assert %{__meta__: %{state: :deleted}} = rule
    end

    test "soft_deletion modifies field deleted_at of rule and associated rule_implementations with the current timestamp" do
      concept_ids = 1..8 |> Enum.to_list() |> Enum.map(&"#{&1}")

      rules =
        ([nil, nil] ++ concept_ids)
        |> Enum.with_index()
        |> Enum.map(fn {id, idx} ->
          [business_concept_id: id, name: "Rule Name #{idx}"]
        end)
        |> Enum.map(&insert(:rule, &1))

      rules
      |> Enum.map(
        &insert(:rule_implementation, %{rule: &1, implementation_key: "ri_of_#{&1.id}"})
      )

      # 2,4,6,8 are deleted
      active_ids = ["1", "3", "5", "7"]

      ts = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, %{rules: {count, _}, impls: {ri_count, _}}} = Rules.soft_deletion(active_ids, ts)

      assert count == 4
      assert ri_count == 4

      {active_rules, deleted_rules} =
        rules
        |> Enum.map(& &1.id)
        |> Enum.map(&Repo.get!(Rule, &1))
        |> Enum.split_with(
          &(is_nil(&1.business_concept_id) or Enum.member?(active_ids, &1.business_concept_id))
        )

      assert Enum.count(active_rules) == 6
      assert Enum.count(deleted_rules) == 4

      assert Enum.all?(active_rules, &is_nil(&1.deleted_at))
      assert Enum.all?(deleted_rules, &(&1.deleted_at == ts))
      assert Enum.map(deleted_rules, & &1.business_concept_id) == ["2", "4", "6", "8"]
    end

    test "list_all_rules retrieves rules which are not deleted" do
      insert(:rule, deleted_at: DateTime.utc_now(), name: "Deleted Rule")
      not_deleted_rule = insert(:rule, name: "Not Deleted Rule")

      assert Rules.list_all_rules()
             |> Enum.map(&Map.get(&1, :id)) == [not_deleted_rule.id]
    end

    test "list_rules/1 retrieves all rules filtered by ids" do
      rule = insert(:rule, deleted_at: DateTime.utc_now(), name: "Rule 1")
      insert(:rule, name: "Rule 2")
      rule_3 = insert(:rule, name: "Rule 3")

      assert [rule.id, rule_3.id]
             |> Rules.list_rules()
             |> Enum.map(&Map.get(&1, :id)) == [rule_3.id]
    end

    test "get_rule_by_implementation_key/1 retrieves a rule" do
      implementation_key = "rik1"
      rule = insert(:rule, name: "Deleted Rule")
      insert(:rule_implementation, implementation_key: implementation_key, rule: rule)

      %{id: result_id} = Rules.get_rule_by_implementation_key(implementation_key)

      assert result_id == Map.get(rule, :id)
    end

    test "get_rule_by_implementation_key/1 retrieves a rule by implementation key" do
      implementation_key = "rik1"
      rule = insert(:rule, name: "Deleted Rule")
      insert(:rule_implementation, implementation_key: implementation_key, rule: rule)

      %{id: result_id} = Rules.get_rule_by_implementation_key(implementation_key)

      assert result_id == Map.get(rule, :id)
    end

    test "get_structures_ids returns ids of all structures present in rule_implementation" do
      creation_attrs = %{
        dataset: [
          %{structure: %{id: 1}},
          %{clauses: [%{left: %{id: 2}, right: %{id: 3}}], structure: %{id: 4}}
        ],
        population: [
          %{
            operator: %{
              group: "gt",
              name: "timestamp_gt_timestamp",
              value_type: "timestamp"
            },
            structure: %{id: 5},
            value: [%{raw: "2019-12-02 05:35:00"}]
          }
        ],
        validations: [
          %{
            operator: %{
              group: "gt",
              name: "timestamp_gt_timestamp",
              value_type: "timestamp"
            },
            structure: %{id: 6},
            value: [%{raw: "2019-12-02 05:35:00"}]
          }
        ]
      }

      implementation_key = "rik1"
      rule = insert(:rule, name: "R1")

      rule_implementaton =
        insert(:rule_implementation,
          implementation_key: implementation_key,
          rule: rule,
          dataset: creation_attrs.dataset,
          population: creation_attrs.population,
          validations: creation_attrs.validations
        )

      structures_ids = Rules.get_structures_ids(rule_implementaton)

      assert Enum.sort(structures_ids) == [1, 2, 3, 4, 5, 6]
    end
  end
end
