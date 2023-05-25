defmodule TdDq.Rules.BulkLoadTest do
  use TdDd.DataCase

  alias TdDq.Rules
  alias TdDq.Rules.BulkLoad

  @moduletag sandbox: :shared

  @rules [%{"name" => "foo_rule"}, %{"name" => "bar_rule"}]

  @hierarchy_template [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "Numeric",
          "name" => "integer",
          "type" => "integer",
          "values" => nil,
          "widget" => "number"
        },
        %{
          "cardinality" => "?",
          "name" => "hierarchy_name_1",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "name" => "hierarchy_name_2",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        }
      ]
    }
  ]

  setup do
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised(TdDq.Cache.RuleLoader)
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")

    %{name: hierarchy_template_name} =
      CacheHelpers.insert_template(scope: "dq", content: @hierarchy_template)

    %{external_id: domain_external_id} = CacheHelpers.insert_domain()
    hierarchy = create_hierarchy()
    CacheHelpers.insert_hierarchy(hierarchy)

    [
      external_id: domain_external_id,
      template_name: template_name,
      hierarchy_template_name: hierarchy_template_name,
      hierarchy: hierarchy,
      claims: build(:claims)
    ]
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

    test "returns ids with hierarchy valid template", %{
      external_id: domain_external_id,
      hierarchy_template_name: template_name,
      hierarchy: %{nodes: nodes},
      claims: claims
    } do
      [%{key: key_node_1}, %{key: key_node_2} | _] = nodes

      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain_external_id)
          |> Map.put("template", template_name)
          |> Map.put("integer", 1)
          |> Map.put("hierarchy_name_1", "children_1")
          |> Map.put("hierarchy_name_2", "father|children_1")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(rules, claims)

      df_content = %{
        "hierarchy_name_1" => key_node_2,
        "hierarchy_name_2" => [key_node_1, key_node_2],
        "integer" => 1
      }

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

    test "return error with hierarchy more than one nodes", %{
      external_id: domain_external_id,
      hierarchy_template_name: template_name,
      claims: claims
    } do
      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain_external_id)
          |> Map.put("template", template_name)
          |> Map.put("integer", 1)
          |> Map.put("hierarchy_name_1", "children_2")
          |> Map.put("hierarchy_name_2", "children_2|children_2")
        end)

      assert {:ok, %{ids: [], errors: [_e1, _e2]}} = BulkLoad.bulk_load(rules, claims)
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

  defp create_hierarchy do
    hierarchy_id = 1

    %{
      id: hierarchy_id,
      name: "name_#{hierarchy_id}",
      nodes: [
        build(:hierarchy_node, %{
          node_id: 1,
          parent_id: nil,
          name: "father",
          path: "/father",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 2,
          parent_id: 1,
          name: "children_1",
          path: "/father/children_1",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 3,
          parent_id: 1,
          name: "children_2",
          path: "/father/children_2",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 4,
          parent_id: nil,
          name: "children_2",
          path: "/children_2",
          hierarchy_id: hierarchy_id
        })
      ]
    }
  end
end
