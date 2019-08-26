defmodule TdDq.RulesTest do
  use TdDq.DataCase
  import Ecto.Query, warn: false
  import TdDq.Factory

  alias Ecto.Changeset
  alias TdDq.MockRelationCache
  alias TdDq.Rule
  alias TdDq.Rules

  setup_all do
    start_supervised(MockRelationCache)
    :ok
  end

  @list_cache [
    %{
      resource_id: 1,
      context: %{
        "system" => "system_1",
        "structure" => "structure_1",
        "structure_id" => "1",
        "group" => "group_1",
        "field" => "field_1"
      },
      resource_type: "data_field"
    },
    %{
      resource_id: 2,
      context: %{
        "system" => "system_2",
        "structure" => "structure_2",
        "structure_id" => "2",
        "group" => "group_2",
        "field" => "field_2"
      },
      resource_type: "data_field"
    },
    %{
      resource_id: 3,
      context: %{
        "system" => "system_3",
        "structure" => "structure_3",
        "structure_id" => "3",
        "group" => "group_3",
        "field" => "field_3"
      },
      resource_type: "data_field"
    }
  ]

  describe "rule" do
    alias TdDq.Rules.Rule

    test "list_rule/0 returns all rules" do
      rule = insert(:rule)
      assert Enum.map(Rules.list_rules(), &rule_preload(&1)) == [rule]
    end

    test "get_rule!/1 returns the rule with given id" do
      rule = insert(:rule)
      assert rule_preload(Rules.get_rule!(rule.id)) == rule
    end

    test "get_rule/1 returns the rule with given id" do
      rule = insert(:rule)
      assert rule_preload(Rules.get_rule!(rule.id)) == rule
    end

    test "get_rule_detail!/2 returns a rule with the possible values for the system params given a group of filters" do
      cache_fixture(@list_cache)

      rule_type =
        insert(
          :rule_type,
          params: %{
            "system_params" => [
              %{"name" => "table", "type" => "string"},
              %{"name" => "ddbb", "type" => "string"}
            ]
          }
        )

      rule = insert(:rule, rule_type: rule_type)

      %{system_values: system_values} = Rules.get_rule_detail!(rule.id)

      assert Enum.all?(Map.keys(system_values), &Enum.member?(["system", "table", "group"], &1))

      system_params_in_response = system_values |> Map.get("system", [])
      table_params_in_response = system_values |> Map.get("table", [])
      group_params_in_response = system_values |> Map.get("group", [])

      system_params_in_resource_list =
        @list_cache |> Enum.map(&(&1 |> Map.get(:context) |> Map.get("system")))

      table_params_in_resource_list =
        @list_cache |> Enum.map(&(&1 |> Map.get(:context) |> Map.get("structure")))

      group_params_in_resource_list =
        @list_cache |> Enum.map(&(&1 |> Map.get(:context) |> Map.get("group")))

      assert system_params_in_response
             |> Enum.all?(fn %{"name" => name} ->
               Enum.member?(system_params_in_resource_list, name)
             end)

      assert table_params_in_response
             |> Enum.all?(fn %{"name" => name} ->
               Enum.member?(table_params_in_resource_list, name)
             end)

      assert group_params_in_response
             |> Enum.all?(fn %{"name" => name} ->
               Enum.member?(group_params_in_resource_list, name)
             end)
    end

    test "create_rule/1 with valid data creates a rule" do
      rule_type = insert(:rule_type)

      creation_attrs =
        Map.from_struct(
          build(
            :rule,
            rule_type_id: rule_type.id
          )
        )

      assert {:ok, %Rule{} = rule} = Rules.create_rule(rule_type, creation_attrs)

      assert rule.rule_type_id == creation_attrs[:rule_type_id]
      assert rule.business_concept_id == creation_attrs[:business_concept_id]
      assert rule.goal == creation_attrs[:goal]
      assert rule.minimum == creation_attrs[:minimum]
      assert rule.name == creation_attrs[:name]
      assert rule.population == creation_attrs[:population]
      assert rule.priority == creation_attrs[:priority]
      assert rule.weight == creation_attrs[:weight]
      assert rule.active == creation_attrs[:active]
      assert rule.version == creation_attrs[:version]
      assert rule.updated_by == creation_attrs[:updated_by]
      assert rule.type_params == creation_attrs[:type_params]
    end

    test "create_rule/1 with invalid data returns error changeset" do
      rule_type = insert(:rule_type)

      creation_attrs = Map.from_struct(build(:rule, rule_type_id: rule_type.id, name: nil))

      assert {:error, %Ecto.Changeset{}} = Rules.create_rule(rule_type, creation_attrs)
    end

    test "create_rule/2 with same name and business concept id returns error changeset" do
      rule_type = insert(:rule_type)
      insert(:rule, rule_type: rule_type)
      creation_attrs = Map.from_struct(build(:rule, rule_type_id: rule_type.id))
      {:error, changeset} = Rules.create_rule(rule_type, creation_attrs)

      errors = Map.get(changeset, :errors)
      assert Enum.any?(errors, fn {key, _} -> key == :rule_name_bc_id end)
    end

    test "create_rule/2 with same name and null business concept id" do
      rule_type = insert(:rule_type)
      insert(:rule, business_concept_id: nil, rule_type: rule_type)

      creation_attrs =
        Map.from_struct(build(:rule, business_concept_id: nil, rule_type_id: rule_type.id))

      {:error, changeset} = Rules.create_rule(rule_type, creation_attrs)

      errors = Map.get(changeset, :errors)
      assert Enum.any?(errors, fn {key, _} -> key == :rule_name_bc_id end)
    end

    test "create_rule/2 two soft deleted rules with same name and bc id can be created" do
      rule_type = insert(:rule_type)
      insert(:rule, rule_type: rule_type, deleted_at: DateTime.utc_now())

      creation_attrs =
        Map.from_struct(build(:rule, rule_type_id: rule_type.id, deleted_at: DateTime.utc_now()))

      {:ok, rule} = Rules.create_rule(rule_type, creation_attrs)

      assert not is_nil(rule.id)
    end

    test "create_rule/2 can create a rule with same name and bc id as a soft deleted rule" do
      rule_type = insert(:rule_type)
      insert(:rule, rule_type: rule_type, deleted_at: DateTime.utc_now())

      creation_attrs = Map.from_struct(build(:rule, rule_type_id: rule_type.id))
      {:ok, rule} = Rules.create_rule(rule_type, creation_attrs)

      assert not is_nil(rule.id)
    end

    test "update_rule/2 with valid data updates the rule" do
      rule = insert(:rule)
      update_attrs = Map.from_struct(rule)

      update_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:description, "New description")
        |> Map.drop([:rule_type_id])

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

      assert rule == rule_preload(Rules.get_rule!(rule.id))
    end

    test "update_rule/2 containing a rule_type_id invalid data returns error changeset" do
      rule = insert(:rule)
      update_attrs = Map.from_struct(rule)

      udpate_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:description, "New description")

      assert {:error, %Ecto.Changeset{}} = Rules.update_rule(rule, udpate_attrs)

      assert rule == rule_preload(Rules.get_rule!(rule.id))
    end

    test "update_rule/2 rule with same name and bc id as an existing rule" do
      rule_type = insert(:rule_type)
      insert(:rule, name: "Reference name", business_concept_id: nil, rule_type: rule_type)

      rule_to_update =
        insert(:rule, name: "Name to Update", business_concept_id: nil, rule_type: rule_type)

      update_attrs =
        rule_to_update
        |> Map.from_struct()
        |> Map.put(:name, "Reference name")
        |> Map.drop([:rule_type_id])

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
      rule_type = insert(:rule_type)

      concept_ids = 1..8 |> Enum.to_list() |> Enum.map(&"#{&1}")

      rules =
        ([nil, nil] ++ concept_ids)
        |> Enum.with_index()
        |> Enum.map(fn {id, idx} ->
          [business_concept_id: id, name: "Rule Name #{idx}", rule_type: rule_type]
        end)
        |> Enum.map(&insert(:rule, &1))

      rules
      |> Enum.map(
        &insert(:rule_implementation, %{rule: &1, implementation_key: "ri_of_#{&1.id}"})
      )

      # 2,4,6,8 are deleted
      active_ids = ["1", "3", "5", "7"]

      ts = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, %{soft_deleted_rules: {count, _}, soft_deleted_implementation_rules: {ri_count, _}}} =
        Rules.soft_deletion(active_ids, ts)

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
      rule_type = insert(:rule_type)
      insert(:rule, deleted_at: DateTime.utc_now(), name: "Deleted Rule", rule_type: rule_type)
      not_deleted_rule = insert(:rule, name: "Not Deleted Rule", rule_type: rule_type)

      assert Rules.list_all_rules()
             |> Enum.map(&Map.get(&1, :id)) == [not_deleted_rule.id]
    end

    test "list_rules/1 retrieves all rules filtered by ids" do
      rule_type = insert(:rule_type)
      rule = insert(:rule, deleted_at: DateTime.utc_now(), name: "Rule 1", rule_type: rule_type)
      insert(:rule, name: "Rule 2", rule_type: rule_type)
      rule_3 = insert(:rule, name: "Rule 3", rule_type: rule_type)

      assert [rule.id, rule_3.id]
             |> Rules.list_rules()
             |> Enum.map(&Map.get(&1, :id)) == [rule_3.id]
    end

    test "get_rule_by_implementation_key/1 retrieves a rule" do
      implementation_key = "rik1"
      rule_type = insert(:rule_type)
      rule = insert(:rule, name: "Deleted Rule", rule_type: rule_type)
      insert(:rule_implementation, implementation_key: implementation_key, rule: rule)

      %{id: result_id, rule_type: rule_type} =
        Rules.get_rule_by_implementation_key(implementation_key)

      assert result_id == Map.get(rule, :id)
      assert rule_type.id == rule |> Map.get(:rule_type) |> Map.get(:id)
    end

    test "get_rule_by_implementation_key/1 retrieves a single rule when there are soft deleted implementation rules with same implementation key" do
      implementation_key = "rik1"
      rule_type = insert(:rule_type)
      rule = insert(:rule, name: "Deleted Rule", rule_type: rule_type)
      insert(:rule_implementation, implementation_key: implementation_key, rule: rule)

      rule2 = insert(:rule, name: "Rule2", rule_type: rule_type)

      insert(:rule_implementation,
        implementation_key: implementation_key,
        rule: rule2,
        deleted_at: DateTime.utc_now()
      )

      %{id: result_id, rule_type: rule_type} =
        Rules.get_rule_by_implementation_key(implementation_key)

      assert result_id == Map.get(rule, :id)
      assert rule_type.id == rule |> Map.get(:rule_type) |> Map.get(:id)
    end

    ## TODO review this test because it is duplicated with previous test
    test "get_last_rule_implementations_result/1 retrieves the last results of a rule implementation" do
      implementation_key = "rik1"
      rule_type = insert(:rule_type)
      rule = insert(:rule, name: "Deleted Rule", rule_type: rule_type)
      insert(:rule_implementation, implementation_key: implementation_key, rule: rule)

      %{id: result_id, rule_type: rule_type} =
        Rules.get_rule_by_implementation_key(implementation_key)

      assert result_id == Map.get(rule, :id)
      assert rule_type.id == rule |> Map.get(:rule_type) |> Map.get(:id)
    end

    test "search_fields/1 retrieves execution_result_info to be indexed in elastic" do
      impl_key_1 = "impl_key_1"
      impl_key_2 = "impl_key_2"
      goal = 20
      expected_avg = (60 + 10) / 2
      expected_message = "quality_result.over_goal"
      rule = insert(:rule, df_content: %{}, business_concept_id: nil, goal: goal)
      rule_impl_1 = insert(:rule_implementation, implementation_key: impl_key_1, rule: rule)
      rule_impl_2 = insert(:rule_implementation, implementation_key: impl_key_2, rule: rule)
      now = DateTime.utc_now()

      insert(
        :rule_result,
        implementation_key: rule_impl_1.implementation_key,
        result: 10,
        date: add_to_date_time(now, -1000)
      )

      insert(
        :rule_result,
        implementation_key: rule_impl_2.implementation_key,
        result: 60,
        date: now
      )

      %{execution_result_info: execution_result_info} = Rule.search_fields(rule)

      %{result_avg: result_avg, result_text: result_text} =
        Map.take(execution_result_info, [:result_avg, :result_text])

      assert result_avg == expected_avg
      assert expected_message == result_text
    end

    defp rule_preload(rule) do
      rule
      |> Repo.preload(:rule_type)
    end

    defp cache_fixture(resources_list) do
      resources_list |> Enum.map(&MockRelationCache.put_relation(&1))
    end
  end

  describe "rule_implementations" do
    alias TdDq.Rules.RuleImplementation

    test "list_rule_implementations/0 returns all rule_implementations" do
      rule_implementation = insert(:rule_implementation)

      assert Enum.map(Rules.list_rule_implementations(), &rule_implementation_preload(&1)) == [
               rule_implementation
             ]
    end

    test "list_rule_implementations/1 returns all rule_implementations by rule" do
      rule_type = insert(:rule_type)
      rule1 = insert(:rule, rule_type: rule_type)
      rule2 = insert(:rule, name: "#{rule1.name} 1", rule_type: rule_type)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      assert length(Rules.list_rule_implementations(%{rule_id: rule1.id})) == 3
    end

    test "list_rule_implementations/1 returns non deleted rule_implementations by rule" do
      rule_type = insert(:rule_type)
      rule1 = insert(:rule, rule_type: rule_type)
      rule2 = insert(:rule, name: "#{rule1.name} 1", rule_type: rule_type)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      insert(:rule_implementation,
        implementation_key: "ri5",
        rule: rule2,
        deleted_at: DateTime.utc_now()
      )

      assert length(Rules.list_rule_implementations(%{rule_id: rule1.id})) == 3
    end

    test "list_rule_implementations/1 returns all rule_implementations by business_concept_id" do
      rule_type = insert(:rule_type)
      rule1 = insert(:rule, rule_type: rule_type, business_concept_id: "xyz")
      rule2 = insert(:rule, rule_type: rule_type)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      assert length(Rules.list_rule_implementations(%{rule: %{business_concept_id: "xyz"}})) == 3
    end

    test "list_rule_implementations/1 returns all rule_implementations by status" do
      rule_type = insert(:rule_type)
      rule1 = insert(:rule, rule_type: rule_type, active: true)
      rule2 = insert(:rule, name: "#{rule1.name} 1", rule_type: rule_type)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      assert length(Rules.list_rule_implementations(%{rule: %{active: true}})) == 3
    end

    test "get_rule_implementation!/1 returns the rule_implementation with given id" do
      rule_implementation = insert(:rule_implementation)

      assert rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id)) ==
               rule_implementation
    end

    test "get_rule_implementation!/1 returns the rule_implementation with given id even if it is soft deleted" do
      rule_implementation = insert(:rule_implementation, deleted_at: DateTime.utc_now())

      assert rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id)) ==
               rule_implementation
    end

    test "get_rule_implementation/1 returns the rule_implementation with given id" do
      rule_implementation = insert(:rule_implementation)

      assert rule_implementation_preload(Rules.get_rule_implementation(rule_implementation.id)) ==
               rule_implementation
    end

    test "get_rule_implementation_by_key/1 returns the rule_implementation with given implementation key" do
      rule_implementation =
        insert(:rule_implementation, implementation_key: "My implementation key")

      assert rule_implementation_preload(
               Rules.get_rule_implementation_by_key(rule_implementation.implementation_key)
             ) == rule_implementation
    end

    test "get_rule_implementation_by_key/1 returns nil if the rule_implementation with given implementation key has been soft deleted" do
      rule_implementation =
        insert(:rule_implementation,
          implementation_key: "My implementation key",
          deleted_at: DateTime.utc_now()
        )

      assert rule_implementation_preload(
               Rules.get_rule_implementation_by_key(rule_implementation.implementation_key)
             ) == nil
    end

    test "create_rule_implementation/1 with valid data creates a rule_implementation" do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: rule.id
          )
        )

      assert {:ok, %RuleImplementation{} = rule_implementation} =
               Rules.create_rule_implementation(rule, creation_attrs)

      assert rule_implementation.rule_id == creation_attrs[:rule_id]
      assert rule_implementation.system_params == creation_attrs[:system_params]
      assert rule_implementation.system == creation_attrs[:system]
    end

    test "create_rule_implementation/1 with valid system fields" do
      rule_type = Rules.get_rule_type_by_name("mandatory_field")
      rule = insert(:rule, rule_type: rule_type, type_params: %{})

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: rule.id,
            system_params: %{"table" => "ttt", "column" => "ccc"}
          )
        )

      assert {:ok, %RuleImplementation{}} = Rules.create_rule_implementation(rule, creation_attrs)
    end

    test "create_rule_implementation/1 with invalid system fields" do
      rule_type = Rules.get_rule_type_by_name("mandatory_field")
      rule = insert(:rule, rule_type: rule_type, type_params: %{})

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: rule.id,
            system_params: %{"Table" => "ttt", "Column" => "ccc"}
          )
        )

      assert {:error, %Changeset{}} = Rules.create_rule_implementation(rule, creation_attrs)
    end

    test "create_rule_implementation/1 with invalid data returns error changeset" do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id, implementation_key: nil, system: nil)
        )

      assert {:error, %Ecto.Changeset{}} = Rules.create_rule_implementation(rule, creation_attrs)
    end

    test "update_rule_implementation/2 with valid data updates the rule_implementation" do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      update_attrs =
        update_attrs
        |> Map.put(:implementation_key, "New implementation_key")
        |> Map.put(:system, "New system")

      assert {:ok, rule_implementation} =
               Rules.update_rule_implementation(rule_implementation, update_attrs)

      assert %RuleImplementation{} = rule_implementation
      assert rule_implementation.rule_id == update_attrs[:rule_id]
      assert rule_implementation.system_params == update_attrs[:system_params]
      assert rule_implementation.system == update_attrs[:system]
    end

    test "update_rule_implementation/2 with invalid data returns error changeset" do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      udpate_attrs =
        update_attrs
        |> Map.put(:name, nil)
        |> Map.put(:system, nil)

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_implementation(rule_implementation, udpate_attrs)

      assert rule_implementation ==
               rule_implementation_preload(Rules.get_rule_implementation!(rule_implementation.id))
    end

    test "delete_rule_implementation/1 deletes the rule_implementation" do
      rule_implementation = insert(:rule_implementation)
      assert {:ok, %RuleImplementation{}} = Rules.delete_rule_implementation(rule_implementation)

      assert_raise Ecto.NoResultsError, fn ->
        Rules.get_rule_implementation!(rule_implementation.id)
      end
    end

    test "change_rule_implementation/1 returns a rule_implementation changeset" do
      rule_implementation = insert(:rule_implementation)
      assert %Ecto.Changeset{} = Rules.change_rule_implementation(rule_implementation)
    end

    defp rule_implementation_preload(rule_implementation) do
      rule_implementation
      |> Repo.preload([:rule, rule: :rule_type])
    end
  end

  describe "rule_type" do
    alias TdDq.Rules.RuleType

    @valid_attrs %{name: "some name", params: %{}}
    @update_attrs %{name: "some updated name", params: %{}}
    @invalid_attrs %{name: nil, params: nil}

    def rule_type_fixture(attrs \\ %{}) do
      {:ok, rule_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Rules.create_rule_type()

      rule_type
    end

    test "list_rule_types/0 returns all rule_type" do
      rule_type = rule_type_fixture()
      assert Enum.member?(Rules.list_rule_types(), rule_type)
    end

    test "get_rule_type!/1 returns the rule_type with given id" do
      rule_type = rule_type_fixture()
      assert Rules.get_rule_type!(rule_type.id) == rule_type
    end

    test "create_rule_type/1 with valid data creates a rule_type" do
      assert {:ok, %RuleType{} = rule_type} = Rules.create_rule_type(@valid_attrs)

      assert rule_type.name == "some name"
      assert rule_type.params == %{}
    end

    test "create_rule_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rules.create_rule_type(@invalid_attrs)
    end

    test "update_rule_type/2 with valid data updates the rule_type" do
      rule_type = rule_type_fixture()

      assert {:ok, rule_type} = Rules.update_rule_type(rule_type, @update_attrs)

      assert %RuleType{} = rule_type
      assert rule_type.name == "some updated name"
      assert rule_type.params == %{}
    end

    test "update_rule_type/2 with invalid data returns error changeset" do
      rule_type = rule_type_fixture()

      assert {:error, %Ecto.Changeset{}} = Rules.update_rule_type(rule_type, @invalid_attrs)

      assert rule_type == Rules.get_rule_type!(rule_type.id)
    end

    test "delete_rule_type/1 deletes the rule_type" do
      rule_type = rule_type_fixture()
      assert {:ok, %RuleType{}} = Rules.delete_rule_type(rule_type)

      assert_raise Ecto.NoResultsError, fn ->
        Rules.get_rule_type!(rule_type.id)
      end
    end

    test "change_rule_type/1 returns a rule_type changeset" do
      rule_type = rule_type_fixture()
      assert %Ecto.Changeset{} = Rules.change_rule_type(rule_type)
    end

    test "create_duplicated_rule_type/1 with valid data creates a rule_type" do
      assert {:ok, %RuleType{} = rule_type} = Rules.create_rule_type(@valid_attrs)

      assert rule_type.name == "some name"
      assert rule_type.params == %{}

      assert {:error, %Ecto.Changeset{} = changeset} = Rules.create_rule_type(@valid_attrs)

      assert changeset.valid? == false

      assert changeset.errors == [
               name:
                 {"has already been taken",
                  [constraint: :unique, constraint_name: "rule_types_name_index"]}
             ]
    end
  end

  describe "rule_result" do
    defp add_to_date_time(datetime, increment) do
      DateTime.from_unix!(DateTime.to_unix(datetime) + increment)
    end

    test "get_last_rule_result/1 returns last rule_implementation rule result" do
      rule_implementation = insert(:rule_implementation)
      now = DateTime.utc_now()

      insert(
        :rule_result,
        implementation_key: rule_implementation.implementation_key,
        result: 10,
        date: add_to_date_time(now, -1000)
      )

      rule_result =
        insert(
          :rule_result,
          implementation_key: rule_implementation.implementation_key,
          result: 60,
          date: now
        )

      insert(
        :rule_result,
        implementation_key: rule_implementation.implementation_key,
        result: 80,
        date: add_to_date_time(now, -2000)
      )

      assert rule_result.result ==
               Rules.get_last_rule_result(rule_implementation.implementation_key).result
    end

    test "get_last_rule_implementations_result/1 retrives last result of each rule implementation" do
      rule = insert(:rule)
      rule_implementation = insert(:rule_implementation, rule: rule)
      now = DateTime.utc_now()

      insert(
        :rule_result,
        implementation_key: rule_implementation.implementation_key,
        result: 10,
        date: add_to_date_time(now, -1000)
      )

      last_rule_result =
        insert(
          :rule_result,
          implementation_key: rule_implementation.implementation_key,
          result: 60,
          date: now
        )

      results = Rules.get_last_rule_implementations_result(rule)
      assert results == [last_rule_result]
    end

    test "list_rule_results/1 retrieves all rule results linked to a rule with existing bc id having a higher result than the goal" do
      rule_type = insert(:rule_type)

      rule_1 =
        insert(:rule,
          rule_type: rule_type,
          name: "Rule 1",
          business_concept_id: "bc_id_1",
          minimum: 90,
          goal: 100
        )

      rule_2 =
        insert(:rule, rule_type: rule_type, name: "Rule 2", business_concept_id: nil, minimum: 70, goal: 80)

      rule_3 =
        insert(:rule,
          rule_type: rule_type,
          name: "Rule 3",
          business_concept_id: "bc_id_3",
          minimum: 70,
          goal: 85
        )

      impl_keys = ["key001", "key002", "key003"]

      rule_impl_1 =
        insert(:rule_implementation, rule: rule_1, implementation_key: Enum.at(impl_keys, 0))

      rule_impl_2 =
        insert(:rule_implementation, rule: rule_2, implementation_key: Enum.at(impl_keys, 1))

      rule_impl_3 =
        insert(:rule_implementation, rule: rule_3, implementation_key: Enum.at(impl_keys, 2))

      rule_result =
        insert(
          :rule_result,
          implementation_key: rule_impl_1.implementation_key,
          result: 55
        )

      rule_result_1 =
        insert(
          :rule_result,
          implementation_key: rule_impl_1.implementation_key,
          result: 92
        )

      rule_result_2 =
        insert(
          :rule_result,
          implementation_key: rule_impl_2.implementation_key,
          result: 75
        )

      rule_result_3 =
        insert(
          :rule_result,
          implementation_key: rule_impl_3.implementation_key,
          result: 75
        )

      rule_result_4 = insert(:rule_result)

      assert Rules.list_rule_results([
               rule_result.id,
               rule_result_1.id,
               rule_result_2.id,
               rule_result_3.id,
               rule_result_4.id
             ]) == [
               %{
                 id: rule_result.id,
                 date: rule_result.date,
                 implementation_key: rule_result.implementation_key,
                 result: rule_result.result,
                 rule_id: rule_1.id,
                 inserted_at: rule_result.inserted_at
               }
             ]
    end
  end
end
