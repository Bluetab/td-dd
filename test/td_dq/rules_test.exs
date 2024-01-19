defmodule TdDq.RulesTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDq.Implementations
  alias TdDq.Rules
  alias TdDq.Rules.Rule

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup_all do
    %{id: domain_id} = domain = CacheHelpers.insert_domain()
    [domain: domain, domain_id: domain_id]
  end

  setup do
    on_exit(fn -> Redix.del!(@stream) end)

    start_supervised!(TdCore.Search.Cluster)
    start_supervised!(TdCore.Search.IndexWorker)
    start_supervised!(TdDd.Search.StructureEnricher)
    start_supervised(TdDq.MockRelationCache)
    start_supervised(TdDq.Cache.RuleLoader)
    [claims: build(:claims)]
  end

  describe "list_rules/0" do
    test "returns all rules" do
      rule = insert(:rule)
      assert Rules.list_rules() == [rule]
    end

    test "returns all rules with preloaded domain", %{domain: domain} do
      rule = insert(:rule, domain_id: domain.id)

      assert Rules.list_rules(%{}, enrich: [:domain]) == [
               %{rule | domain: Map.take(domain, [:id, :external_id, :name])}
             ]
    end
  end

  describe "get_rule/1" do
    test "returns the rule with given id" do
      rule = insert(:rule)
      assert Rules.get_rule!(rule.id) == rule
    end

    test "returns the rule with enriched attributes", %{domain: %{id: domain_id} = domain} do
      rule = insert(:rule, domain_id: domain_id)

      assert Rules.get_rule!(rule.id, enrich: [:domain]) == %{
               rule
               | domain: Map.take(domain, [:id, :name, :external_id])
             }
    end
  end

  describe "create_rule/2" do
    test "creates a rule with valid data", %{claims: claims, domain_id: domain_id} do
      params = string_params_for(:rule, domain_id: domain_id)
      assert {:ok, %{rule: _rule}} = Rules.create_rule(params, claims)
    end

    test "publishes an audit event", %{claims: claims, domain_id: domain_id} do
      params = string_params_for(:rule, domain_id: domain_id)
      assert {:ok, %{audit: event_id}} = Rules.create_rule(params, claims)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end

    test "returns error and changeset if changeset is invalid", %{
      claims: claims,
      domain_id: domain_id
    } do
      params = string_params_for(:rule, name: nil, domain_id: domain_id)
      assert {:error, :rule, %Ecto.Changeset{}, _} = Rules.create_rule(params, claims)
    end

    test "returns error and changeset if domain id is not provided", %{claims: claims} do
      params = string_params_for(:rule, domain_id: nil)

      assert {:error, :rule,
              %Ecto.Changeset{errors: [domain_id: {"required", [validation: :required]}]},
              _} = Rules.create_rule(params, claims)
    end
  end

  describe "update_rule/3" do
    test "updates rule if changes are valid", %{claims: claims, domain_id: domain_id} do
      rule = insert(:rule, domain_id: domain_id)
      params = %{"name" => "New name", "description" => %{"document" => "New description"}}
      assert {:ok, %{rule: _rule}} = Rules.update_rule(rule, params, claims)
    end

    test "updates domain id if its valid", %{claims: claims, domain_id: domain_id} do
      rule = insert(:rule)
      params = %{"domain_id" => domain_id}
      assert {:ok, %{rule: %{domain_id: ^domain_id}}} = Rules.update_rule(rule, params, claims)
      params = %{"domain_id" => nil}

      assert {:error, :rule,
              %Ecto.Changeset{errors: [domain_id: {"required", [validation: :required]}]},
              _} = Rules.update_rule(rule, params, claims)
    end

    test "updates a rule's implementations if the domain_id changes", %{
      claims: claims,
      domain_id: domain_id
    } do
      %{id: rule_id} = rule = insert(:rule)

      implementations = Enum.map(1..5, fn _ -> insert(:implementation, rule_id: rule_id) end)
      insert(:implementation, rule_id: rule_id, domain_id: domain_id)

      params = %{"domain_id" => domain_id}
      assert {:ok, multi} = Rules.update_rule(rule, params, claims)
      assert %{rule: %{domain_id: ^domain_id}} = multi
      assert %{implementations: {5, ids}} = multi
      assert_lists_equal(implementations, ids, &(&1.id == &2))
    end

    test "publishes an audit event", %{claims: claims} do
      rule = insert(:rule)
      params = %{"name" => "New name"}
      assert {:ok, %{audit: event_id}} = Rules.update_rule(rule, params, claims)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end

    test "returns error and changeset if changeset is invalid", %{claims: claims} do
      rule = insert(:rule)
      params = %{name: nil}
      assert {:error, :rule, %Ecto.Changeset{}, _} = Rules.update_rule(rule, params, claims)
    end
  end

  describe "rule" do
    test "delete_rule/1 deletes the rule", %{claims: claims} do
      rule = insert(:rule)
      assert {:ok, %{rule: rule}} = Rules.delete_rule(rule, claims)
      assert %{active: false, deleted_at: deleted_at} = rule
      assert deleted_at !== nil
    end

    test "soft_deletion modifies field deleted_at of rule and associated implementations with the current timestamp" do
      concept_ids = Enum.to_list(1..8)

      rules =
        ([nil, nil] ++ concept_ids)
        |> Enum.with_index()
        |> Enum.map(fn {id, idx} -> [business_concept_id: id, name: "Rule Name #{idx}"] end)
        |> Enum.map(&insert(:rule, &1))

      for %{id: id} <- rules do
        insert(:implementation, rule_id: id, implementation_key: "ri_of_#{id}")
      end

      # 2,4,6,8 are deleted
      active_ids = [1, 3, 5, 7]

      ts = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok, %{rules: {count, _}, deprecated: {ri_count, _}}} = Rules.soft_deletion(active_ids, ts)

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
      assert Enum.map(deleted_rules, & &1.business_concept_id) == [2, 4, 6, 8]
    end

    test "soft_deletion modifies field deleted_at and status of associated implementations" do
      %{id: rule_id} = insert(:rule)

      %{id: implementation_id} =
        insert(:implementation, rule_id: rule_id, implementation_key: "ri_of_#{rule_id}")

      {:ok, _} = Rules.soft_deletion([rule_id], DateTime.truncate(DateTime.utc_now(), :second))

      %{status: status} = Implementations.get_implementation!(implementation_id)

      assert status == :deprecated
    end

    test "list_rules/1 retrieves all rules filtered by ids" do
      rule = insert(:rule, deleted_at: DateTime.utc_now(), name: "Rule 1")
      insert(:rule, name: "Rule 2")
      rule_3 = insert(:rule, name: "Rule 3")

      assert [rule.id, rule_3.id]
             |> Rules.list_rules()
             |> Enum.map(&Map.get(&1, :id)) == [rule_3.id]
    end
  end
end
