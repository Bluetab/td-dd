defmodule TdDq.RulesTest do
  use TdDq.DataCase

  import Ecto.Query, warn: false
  import TdDq.Factory

  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Rule
  alias TdDq.Rules
  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(MockRelationCache)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  describe "rule" do
    alias TdDq.Rules.Rule

    test "list_rule/0 returns all rules" do
      rule = insert(:rule)
      assert Rules.list_rules() == [rule]
    end

    test "get_rule/1 returns the rule with given id" do
      rule = insert(:rule)
      assert Rules.get_rule!(rule.id) == rule
    end

    test "create_rule/1 with valid data creates a rule" do
      creation_attrs = Map.from_struct(build(:rule))

      assert {:ok, %Rule{} = rule} = Rules.create_rule(creation_attrs)

      assert rule.business_concept_id == creation_attrs[:business_concept_id]
      assert rule.goal == creation_attrs[:goal]
      assert rule.minimum == creation_attrs[:minimum]
      assert rule.name == creation_attrs[:name]
      assert rule.active == creation_attrs[:active]
      assert rule.version == creation_attrs[:version]
      assert rule.updated_by == creation_attrs[:updated_by]
    end

    test "create_rule/1 with invalid data returns error changeset" do
      creation_attrs = Map.from_struct(build(:rule, name: nil))

      assert {:error, %Ecto.Changeset{}} = Rules.create_rule(creation_attrs)
    end

    test "create_rule/2 with same name and business concept id returns error changeset" do
      insert(:rule)
      creation_attrs = Map.from_struct(build(:rule))
      {:error, changeset} = Rules.create_rule(creation_attrs)

      errors = Map.get(changeset, :errors)
      assert Enum.any?(errors, fn {key, _} -> key == :rule_name_bc_id end)
    end

    test "create_rule/2 with same name and null business concept id" do
      insert(:rule, business_concept_id: nil)

      creation_attrs = Map.from_struct(build(:rule, business_concept_id: nil))

      {:error, changeset} = Rules.create_rule(creation_attrs)

      errors = Map.get(changeset, :errors)
      assert Enum.any?(errors, fn {key, _} -> key == :rule_name_bc_id end)
    end

    test "create_rule/2 two soft deleted rules with same name and bc id can be created" do
      insert(:rule, deleted_at: DateTime.utc_now())

      creation_attrs = Map.from_struct(build(:rule, deleted_at: DateTime.utc_now()))

      {:ok, rule} = Rules.create_rule(creation_attrs)

      assert not is_nil(rule.id)
    end

    test "create_rule/2 can create a rule with same name and bc id as a soft deleted rule" do
      insert(:rule, deleted_at: DateTime.utc_now())

      creation_attrs = Map.from_struct(build(:rule))
      {:ok, rule} = Rules.create_rule(creation_attrs)

      assert not is_nil(rule.id)
    end

    test "update_rule/2 with valid data updates the rule" do
      rule = insert(:rule)
      update_attrs = Map.from_struct(rule)

      update_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:description, %{"document" => "New description"})

      assert {:ok, rule} = Rules.update_rule(rule, update_attrs)
      assert %Rule{} = rule
      assert rule.description == update_attrs[:description]
    end

    test "update_rule/2 with invalid data returns error changeset" do
      rule = insert(:rule)
      update_attrs = Map.from_struct(rule)

      udpate_attrs =
        update_attrs
        |> Map.put(:name, nil)
        |> Map.put(:system, nil)

      assert {:error, %Ecto.Changeset{}} = Rules.update_rule(rule, udpate_attrs)
    end

    test "update_rule/2 rule with same name and bc id as an existing rule" do
      insert(:rule, name: "Reference name", business_concept_id: nil)

      rule_to_update = insert(:rule, name: "Name to Update", business_concept_id: nil)

      update_attrs =
        rule_to_update
        |> Map.from_struct()
        |> Map.put(:name, "Reference name")

      assert {:error, changeset} = Rules.update_rule(rule_to_update, update_attrs)
      errors = Map.get(changeset, :errors)
      assert Enum.any?(errors, fn {key, _} -> key == :rule_name_bc_id end)
    end

    test "delete_rule/1 deletes the rule" do
      rule = insert(:rule)
      assert {:ok, %Rule{}} = Rules.delete_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule!(rule.id) end
    end

    test "change_rule/1 returns a rule changeset" do
      rule = insert(:rule)
      assert %Ecto.Changeset{} = Rules.change_rule(rule)
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

    test "get_rule_by_implementation_key/1 retrieves a single rule when there are soft deleted implementation rules with same implementation key" do
      implementation_key = "rik1"
      rule = insert(:rule, name: "Deleted Rule")
      insert(:rule_implementation, implementation_key: implementation_key, rule: rule)

      rule2 = insert(:rule, name: "Rule2")

      insert(:rule_implementation,
        implementation_key: implementation_key,
        rule: rule2,
        deleted_at: DateTime.utc_now()
      )

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
      creation_attrs =
        %{
          dataset: [
            %{structure: %{id: 1}},
            %{left: %{id: 2}, right: %{id: 3}, structure: %{id: 4}}
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

      rule_implementaton = insert(:rule_implementation,
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
