defmodule TdDq.RulesTest do
  use TdDq.DataCase
  import Ecto.Query, warn: false
  import TdDq.Factory

  alias Ecto.Changeset
  alias TdDq.MockRelationCache
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
      assert rule.description == creation_attrs[:description]
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
      assert Enum.any?(errors, fn {key, _} -> key == :unique_rule_name_bc_id end)
    end

    test "create_rule/2 with same name and null business concept id" do
      rule_type = insert(:rule_type)
      insert(:rule, business_concept_id: nil, rule_type: rule_type)
      creation_attrs = Map.from_struct(build(:rule, business_concept_id: nil, rule_type_id: rule_type.id))
      {:error, changeset} = Rules.create_rule(rule_type, creation_attrs)

      errors = Map.get(changeset, :errors)
      assert Enum.any?(errors, fn {key, _} -> key == :unique_rule_name_bc_id end)
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

    test "delete_rule/1 deletes the rule" do
      rule = insert(:rule)
      assert {:ok, %Rule{}} = Rules.delete_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule!(rule.id) end
    end

    test "change_rule/1 returns a rule changeset" do
      rule = insert(:rule)
      assert %Ecto.Changeset{} = Rules.change_rule(rule)
    end

    test "soft_deletion modifies field deleted_at with the current timestam" do
      rule_type = insert(:rule_type)

      # Rules with nil business_concept_id
      insert(:rule, business_concept_id: nil, name: "Rule Name", rule_type: rule_type)
      insert(:rule, business_concept_id: nil, name: "Rule Name 1", rule_type: rule_type)

      # Rules with business_concept_id to delete
      bc_id_d_1 =
        insert(
          :rule,
          business_concept_id: "bc id to delete",
          name: "Rule Name 2",
          rule_type: rule_type
        )

      bc_id_d_2 =
        insert(
          :rule,
          business_concept_id: "bc id to delete 2",
          name: "Rule Name 3",
          rule_type: rule_type
        )

      bcs_to_delete = [bc_id_d_1.business_concept_id, bc_id_d_2.business_concept_id]

      # Rules with business_concept_id to not delete
      bc_id_nd_1 =
        insert(
          :rule,
          business_concept_id: "bc id to not delete",
          name: "Rule Name 4",
          rule_type: rule_type
        )

      bc_id_nd_2 =
        insert(
          :rule,
          business_concept_id: "bc id to not delete 2",
          name: "Rule Name 5",
          rule_type: rule_type
        )

      bcs_to_avoid_deletion = [bc_id_nd_1.business_concept_id, bc_id_nd_2.business_concept_id]

      Rules.soft_deletion(bcs_to_delete, bcs_to_avoid_deletion)
      result_list = Rule |> Repo.all()

      nil_deleted_at_list = result_list |> Enum.filter(&is_nil(&1.deleted_at))
      not_nil_deleted_at_list = result_list |> Enum.filter(&(not is_nil(&1.deleted_at)))

      assert length(nil_deleted_at_list) == 4
      assert length(not_nil_deleted_at_list) == 2

      assert bcs_to_delete
             |> Enum.all?(fn b_c ->
               not_nil_deleted_at_list |> Enum.any?(&(&1.business_concept_id == b_c))
             end)

      assert bcs_to_avoid_deletion
             |> Enum.all?(fn b_c ->
               nil_deleted_at_list |> Enum.any?(&(&1.business_concept_id == b_c))
             end)

      assert length(
               Enum.filter(
                 nil_deleted_at_list,
                 &(&1.deleted_at == nil && &1.business_concept_id == nil)
               )
             ) == 2
    end

    test "list_all_rules retrieves rules which are not deleted" do
      rule_type = insert(:rule_type)
      insert(:rule, deleted_at: DateTime.utc_now(), name: "Deleted Rule", rule_type: rule_type)
      not_deleted_rule = insert(:rule, name: "Not Deleted Rule", rule_type: rule_type)

      assert Rules.list_all_rules()
             |> Enum.map(&Map.get(&1, :id)) == [not_deleted_rule.id]
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

    test "get_rule_implementation_by_key!/1 returns the rule_implementation with given implementation key" do
      rule_implementation =
        insert(:rule_implementation, implementation_key: "My implementation key")

      assert rule_implementation_preload(
               Rules.get_rule_implementation_by_key!(rule_implementation.implementation_key)
             ) == rule_implementation
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
      assert rule_implementation.description == creation_attrs[:description]
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
        |> Map.put(:description, "New description")

      assert {:ok, rule_implementation} =
               Rules.update_rule_implementation(rule_implementation, update_attrs)

      assert %RuleImplementation{} = rule_implementation
      assert rule_implementation.rule_id == update_attrs[:rule_id]
      assert rule_implementation.description == update_attrs[:description]
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
      assert changeset.errors == [name: {"has already been taken", []}]
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
  end
end
