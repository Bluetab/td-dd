defmodule TdDq.Rules.BulkLoadTest do
  use TdDd.DataCase

  alias TdDq.Rules
  alias TdDq.Rules.BulkLoad

  @moduletag sandbox: :shared

  @rules [%{"name" => "foo_rule"}, %{"name" => "bar_rule"}]

  setup do
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised(TdDq.Cache.RuleLoader)
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    %{external_id: domain_external_id} = CacheHelpers.insert_domain()

    [external_id: domain_external_id, template_name: template_name, claims: build(:claims)]
  end

  describe "bulk_load/2" do
    @tag authentication: [role: "admin"]

    test "return ids from inserted rules", %{external_id: external_id, claims: claims} do
      rules =
        Enum.map(@rules, fn rule ->
          Map.put(rule, "domain_external_id", external_id)
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(rules, claims)
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

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(rules, claims)

      df_content = %{"string" => "initial", "list" => "one"}

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "returns ids with valid template with multiple field", %{
      external_id: domain_external_id,
      claims: claims
    } do
      template_content = [
        %{
          "fields" => [
            %{
              "name" => "multi_string",
              "type" => "string",
              "cardinality" => "*"
            }
          ],
          "name" => "group_name0"
        }
      ]

      %{name: template_name} =
        CacheHelpers.insert_template(
          scope: "dq",
          content: template_content
        )

      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain_external_id)
          |> Map.put("template", template_name)
          |> Map.put("multi_string", "a|b|c")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(rules, claims)

      df_content = %{"multi_string" => ["a", "b", "c"]}

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "return error when domain_external_id not exit", %{
      external_id: domain_external_id,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 = Map.put(rule1, "domain_external_id", domain_external_id)
      %{"name" => name} = rule2 = Map.put(rule2, "domain_external_id", "foo")

      assert {:ok, %{ids: [id], errors: [error]}} = BulkLoad.bulk_load([rule1, rule2], claims)

      assert %{name: "foo_rule"} = Rules.get_rule(id)
      assert %{rule_name: ^name, message: _} = error
    end

    test "return error with invalid df_content", %{
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

      assert {:ok, %{ids: [], errors: [_e1, _e2]}} = BulkLoad.bulk_load([rule1, rule2], claims)
    end

    test "return ids with a description", %{
      external_id: domain_external_id,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 =
        rule1
        |> Map.put("domain_external_id", domain_external_id)
        |> Map.put("description", "bar")

      rule2 =
        rule2
        |> Map.put("domain_external_id", domain_external_id)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load([rule1, rule2], claims)

      description = %{
        "document" => %{
          "nodes" => [
            %{
              "nodes" => [%{"leaves" => [%{"text" => "bar"}], "object" => "text"}],
              "object" => "block",
              "type" => "paragraph"
            }
          ]
        }
      }

      assert %{description: ^description} = Rules.get_rule(id1)
      %{description: rule2description} = Rules.get_rule(id2)
      assert true = Enum.empty?(rule2description)
    end
  end
end
