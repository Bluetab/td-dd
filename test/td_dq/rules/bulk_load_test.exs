defmodule TdDq.Rules.BulkLoadTest do
  use TdDd.DataCase

  alias TdDq.Rules
  alias TdDq.Rules.BulkLoad

  @moduletag sandbox: :shared

  @rules [
    %{
      "name" => "foo_rule",
      "description" => "foo_description"
    },
    %{
      "name" => "bar_rule",
      "description" => "bar_description"
    }
  ]

  setup do
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised(TdDq.Cache.RuleLoader)
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    %{external_id: domain_external_id} = CacheHelpers.insert_domain()

    [external_id: domain_external_id, template_name: template_name, claims: build(:dq_claims)]
  end

  describe "bulk_load/2" do
    test "return ids from inserted rules", %{external_id: external_id, claims: claims} do
      rules =
        Enum.map(@rules, fn rule ->
          Map.put(rule, "domain_external_id", external_id)
        end)

      assert %{ids: [id1, id2], errors: []} = BulkLoad.bulk_load(rules, claims)
      assert %{name: "foo_rule"} = Rules.get_rule(id1)
      assert %{name: "bar_rule"} = Rules.get_rule(id2)
    end

    test "returns ids with valid template", %{
      external_id: domain_external_id,
      template_name: template_name,
      claims: claims
    } do
      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain_external_id)
          |> Map.put("template", template_name)
          |> Map.put("string", "initial")
          |> Map.put("list", "one")
        end)

      assert %{ids: [id1, id2], errors: []} = BulkLoad.bulk_load(rules, claims)
      assert %{name: "foo_rule"} = Rules.get_rule(id1)
      assert %{name: "bar_rule"} = Rules.get_rule(id2)
    end

    test "return error when domain not exits", %{
      external_id: domain_external_id,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 = Map.put(rule1, "domain_external_id", domain_external_id)
      %{"name" => name} = rule2 = Map.put(rule2, "domain_external_id", "foo")

      assert %{ids: [id], errors: [error]} = BulkLoad.bulk_load([rule1, rule2], claims)

      assert %{name: "foo_rule"} = Rules.get_rule(id)
      assert %{rule_name: ^name, message: _} = error
    end

    test "return error with invalid df_contet", %{
      external_id: domain_external_id,
      template_name: template_name,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 =
        rule1
        |> Map.put("domain_external_id", domain_external_id)
        |> Map.put("template", template_name)
        |> Map.put("df_invalid", "baz")

      rule2 =
        rule2
        |> Map.put("domain_external_id", domain_external_id)
        |> Map.put("template", "xwy")

      assert %{ids: [], errors: errors} = BulkLoad.bulk_load([rule1, rule2], claims)
      assert 2 == length(errors)
    end
  end
end
