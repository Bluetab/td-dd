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

  @user_field_template [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "default" => %{"value" => "", "origin" => "user"},
          "label" => "User",
          "name" => "data_owner",
          "type" => "user",
          "values" => %{"processed_users" => [], "role_users" => "Data Owner"},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "default" => %{"value" => "", "origin" => "user"},
          "label" => "User list",
          "name" => "data_owner_multiple",
          "type" => "user",
          "values" => %{"processed_users" => [], "role_users" => "Data Owner"},
          "widget" => "dropdown"
        }
      ]
    }
  ]

  @default_lang "en"

  setup do
    start_supervised(TdDq.Cache.RuleLoader)
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")

    %{name: hierarchy_template_name} =
      CacheHelpers.insert_template(scope: "dq", content: @hierarchy_template)

    %{name: user_field_template_name} =
      CacheHelpers.insert_template(scope: "dq", content: @user_field_template)

    domain = CacheHelpers.insert_domain()
    hierarchy = create_hierarchy()
    CacheHelpers.insert_hierarchy(hierarchy)

    [
      domain: domain,
      template_name: template_name,
      hierarchy_template_name: hierarchy_template_name,
      user_field_template_name: user_field_template_name,
      hierarchy: hierarchy,
      claims: build(:claims)
    ]
  end

  describe "bulk_load/3" do
    @tag authentication: [role: "admin"]

    test "return ids from inserted rules", %{domain: domain, claims: claims} do
      rules =
        Enum.map(@rules, fn rule ->
          Map.put(rule, "domain_external_id", domain.external_id)
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} =
               BulkLoad.bulk_load(rules, claims, @default_lang)

      assert %{name: "foo_rule"} = Rules.get_rule(id1)
      assert %{name: "bar_rule"} = Rules.get_rule(id2)
    end

    test "returns ids with valid template", %{
      domain: domain,
      template_name: template_name,
      claims: claims
    } do
      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("string", "initial")
          |> Map.put("list", "one")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} =
               BulkLoad.bulk_load(rules, claims, @default_lang)

      df_content = %{
        "string" => %{"value" => "initial", "origin" => "file"},
        "list" => %{"value" => "one", "origin" => "file"}
      }

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "returns ids with hierarchy valid template", %{
      domain: domain,
      hierarchy_template_name: template_name,
      hierarchy: %{nodes: nodes},
      claims: claims
    } do
      [%{key: key_node_1}, %{key: key_node_2} | _] = nodes

      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("integer", 1)
          |> Map.put("hierarchy_name_1", "children_1")
          |> Map.put("hierarchy_name_2", "father|children_1")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} =
               BulkLoad.bulk_load(rules, claims, @default_lang)

      df_content = %{
        "hierarchy_name_1" => %{"value" => key_node_2, "origin" => "file"},
        "hierarchy_name_2" => %{"value" => [key_node_1, key_node_2], "origin" => "file"},
        "integer" => %{"value" => 1, "origin" => "file"}
      }

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "returns ids with valid template with multiple field", %{
      domain: domain,
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
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("multi_string", "a|b|c")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} =
               BulkLoad.bulk_load(rules, claims, @default_lang)

      df_content = %{"multi_string" => %{"value" => ["a", "b", "c"], "origin" => "file"}}

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "returns ids with valid template that include fixed values translated with single cardinality",
         %{
           domain: domain,
           claims: claims
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "label_i18n",
              "name" => "i18n",
              "type" => "string",
              "values" => %{"fixed" => ["one", "two", "three"]}
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

      CacheHelpers.put_i18n_message("es", %{
        message_id: "fields.label_i18n.one",
        definition: "uno"
      })

      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("i18n", "uno")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(rules, claims, "es")

      df_content = %{"i18n" => %{"value" => "one", "origin" => "file"}}

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "returns ids with valid template that include fixed values translated with multiple cardinality",
         %{
           domain: domain,
           claims: claims
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "+",
              "label" => "label_i18n",
              "name" => "i18n",
              "type" => "string",
              "values" => %{"fixed" => ["one", "two", "three"]}
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

      CacheHelpers.put_i18n_messages("es", [
        %{message_id: "fields.label_i18n.one", definition: "uno"},
        %{message_id: "fields.label_i18n.two", definition: "dos"},
        %{message_id: "fields.label_i18n.three", definition: "tres"}
      ])

      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("i18n", "uno|tres")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(rules, claims, "es")

      df_content = %{"i18n" => %{"value" => ["one", "three"], "origin" => "file"}}

      assert %{df_content: ^df_content} = Rules.get_rule(id1)
      assert %{df_content: ^df_content} = Rules.get_rule(id2)
    end

    test "returns ids with valid template that include fixed values without i18n key and single cardinality",
         %{
           domain: domain,
           claims: claims
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "label_i18n",
              "name" => "i18n",
              "type" => "string",
              "values" => %{"fixed" => ["one", "two", "three"]}
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
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("i18n", "uno")
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{
                    message: %{df_content: ["i18n: is invalid"]},
                    rule_name: "foo_rule"
                  },
                  %{
                    message: %{df_content: ["i18n: is invalid"]},
                    rule_name: "bar_rule"
                  }
                ]
              }} = BulkLoad.bulk_load(rules, claims, "es")
    end

    test "returns ids with valid template that include fixed values without i18n key and multiple cardinality",
         %{
           domain: domain,
           claims: claims
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "+",
              "label" => "label_i18n",
              "name" => "i18n",
              "type" => "string",
              "values" => %{"fixed" => ["one", "two", "three"]}
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
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("i18n", "uno|tres")
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{
                    message: %{df_content: ["i18n: has an invalid entry"]},
                    rule_name: "foo_rule"
                  },
                  %{
                    message: %{df_content: ["i18n: has an invalid entry"]},
                    rule_name: "bar_rule"
                  }
                ]
              }} = BulkLoad.bulk_load(rules, claims, "es")
    end

    test "return error when domain_external_id not exit", %{
      domain: domain,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 = Map.put(rule1, "domain_external_id", domain.external_id)
      %{"name" => name} = rule2 = Map.put(rule2, "domain_external_id", "foo")

      assert {:ok, %{ids: [id], errors: [error]}} =
               BulkLoad.bulk_load([rule1, rule2], claims, @default_lang)

      assert %{name: "foo_rule"} = Rules.get_rule(id)
      assert %{rule_name: ^name, message: _} = error
    end

    test "return error with invalid df_content", %{
      domain: domain,
      template_name: template_name,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 =
        rule1
        |> Map.put("domain_external_id", domain.external_id)
        |> Map.put("template", template_name)
        |> Map.put("df_invalid", "baz")

      rule2 =
        rule2
        |> Map.put("domain_external_id", domain.external_id)
        |> Map.put("template", "xwy")

      assert {:ok, %{ids: [], errors: [_e1, _e2]}} =
               BulkLoad.bulk_load([rule1, rule2], claims, @default_lang)
    end

    test "return error with hierarchy more than one nodes", %{
      domain: domain,
      hierarchy_template_name: template_name,
      claims: claims
    } do
      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("domain_external_id", domain.external_id)
          |> Map.put("template", template_name)
          |> Map.put("integer", 1)
          |> Map.put("hierarchy_name_1", "children_2")
          |> Map.put("hierarchy_name_2", "children_2|children_2")
        end)

      assert {:ok, %{ids: [], errors: [_e1, _e2]}} =
               BulkLoad.bulk_load(rules, claims, @default_lang)
    end

    test "return ids with a description", %{
      domain: domain,
      claims: claims
    } do
      [rule1, rule2] = @rules

      rule1 =
        rule1
        |> Map.put("domain_external_id", domain.external_id)
        |> Map.put("description", "bar")

      rule2 = Map.put(rule2, "domain_external_id", domain.external_id)

      assert {:ok, %{ids: [id1, id2], errors: []}} =
               BulkLoad.bulk_load([rule1, rule2], claims, @default_lang)

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

    test "creates rule under valid user field value", %{
      user_field_template_name: template_name,
      domain: domain,
      claims: claims
    } do
      full_name = "user"
      full_name1 = "user1"
      full_name2 = "user2"

      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("data_owner", full_name)
          |> Map.put("data_owner_multiple", "#{full_name1}|#{full_name2}")
          |> Map.put("template", template_name)
          |> Map.put("domain_external_id", domain.external_id)
        end)

      user = CacheHelpers.insert_user(full_name: full_name)
      user1 = CacheHelpers.insert_user(full_name: full_name1)
      user2 = CacheHelpers.insert_user(full_name: full_name2)
      CacheHelpers.insert_acl(domain.id, "Data Owner", [user.id, user1.id, user2.id])

      assert {:ok, %{ids: [id1, id2], errors: []}} =
               BulkLoad.bulk_load(rules, claims, @default_lang)

      assert Repo.get!(Rules.Rule, id1).df_content == %{
               "data_owner" => %{"value" => full_name, "origin" => "file"},
               "data_owner_multiple" => %{"value" => [full_name1, full_name2], "origin" => "file"}
             }

      assert Repo.get!(Rules.Rule, id2).df_content == %{
               "data_owner" => %{"value" => full_name, "origin" => "file"},
               "data_owner_multiple" => %{"value" => [full_name1, full_name2], "origin" => "file"}
             }
    end

    test "returns error under invalid user field value", %{
      user_field_template_name: template_name,
      domain: domain,
      claims: claims
    } do
      rules =
        Enum.map(@rules, fn rule ->
          rule
          |> Map.put("data_owner", "invalid_user_name")
          |> Map.put("template", template_name)
          |> Map.put("domain_external_id", domain.external_id)
        end)

      user = CacheHelpers.insert_user(full_name: "user")
      CacheHelpers.insert_acl(domain.id, "Data Owner", [user.id])

      assert {:ok, %{ids: [], errors: errors}} = BulkLoad.bulk_load(rules, claims, @default_lang)
      assert Enum.count(errors) == 2

      assert Enum.all?(errors, fn %{message: %{df_content: [error]}} ->
               error == "data_owner: is invalid"
             end)
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
