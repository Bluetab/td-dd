defmodule TdDq.Implementations.BulkLoadTest do
  use TdDd.DataCase

  alias TdDq.Implementations
  alias TdDq.Implementations.BulkLoad

  @moduletag sandbox: :shared

  @valid_implementation [
    %{
      "goal" => "100",
      "implementation_key" => "boo",
      "minimum" => "10",
      "result_type" => "percentage"
    },
    %{
      "goal" => "10",
      "implementation_key" => "bar",
      "minimum" => "100",
      "result_type" => "errors_number"
    }
  ]

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
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")

    %{name: hierarchy_template_name} =
      CacheHelpers.insert_template(scope: "ri", content: @hierarchy_template)

    hierarchy = create_hierarchy()
    CacheHelpers.insert_hierarchy(hierarchy)
    domain = CacheHelpers.insert_domain()

    [
      rule: insert(:rule),
      claims: build(:claims),
      template_name: template_name,
      domain: domain,
      hierarchy: hierarchy,
      hierarchy_template_name: hierarchy_template_name
    ]
  end

  describe "bulk_load/2" do
    @tag authentication: [role: "admin"]

    test "return ids from inserted implementations", %{rule: %{name: rule_name}, claims: claims} do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          Map.put(imp, "rule_name", rule_name)
        end)

      assert {:ok, %{ids: [id2, id1], errors: []}} = BulkLoad.bulk_load(imp, claims)

      assert %{implementation_key: "boo"} = Implementations.get_implementation!(id1)
      assert %{implementation_key: "bar"} = Implementations.get_implementation!(id2)
    end

    test "return ids from inserted implementations without rule", %{claims: claims} do
      %{external_id: domain_external_id} = CacheHelpers.insert_domain()

      imp =
        Enum.map(@valid_implementation, fn imp ->
          Map.put(imp, "domain_external_id", domain_external_id)
        end)

      assert {:ok, %{ids: [id2, id1], errors: []}} = BulkLoad.bulk_load(imp, claims)

      assert %{implementation_key: "boo"} = Implementations.get_implementation!(id1)
      assert %{implementation_key: "bar"} = Implementations.get_implementation!(id2)
    end

    test "return ids with valid df_content", %{
      rule: %{name: rule_name},
      claims: claims,
      template_name: template_name
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", template_name)
          |> Map.put("string", "initial")
          |> Map.put("list", "one")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(imp, claims)

      df_content = %{"string" => "initial", "list" => "one"}

      assert %{df_content: ^df_content} = Implementations.get_implementation!(id1)
      assert %{df_content: ^df_content} = Implementations.get_implementation!(id2)
    end

    test "return ids with valid df_content that include domain_external_id", %{
      rule: %{name: rule_name},
      claims: claims,
      domain: %{external_id: domain_external_id, id: domain_id}
    } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "label0",
              "name" => "string",
              "type" => "string",
              "values" => nil
            },
            %{
              "cardinality" => "1",
              "label" => "label1",
              "name" => "list",
              "type" => "list",
              "values" => %{"fixed" => ["one", "two", "three"]}
            },
            %{
              "name" => "my_domain",
              "type" => "domain",
              "label" => "My domain",
              "values" => nil,
              "widget" => "dropdown",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      %{name: template_name} =
        CacheHelpers.insert_template(
          scope: "ri",
          content: template_content
        )

      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", template_name)
          |> Map.put("string", "initial")
          |> Map.put("list", "one")
          |> Map.put("my_domain", domain_external_id)
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(imp, claims)

      df_content = %{"string" => "initial", "list" => "one", "my_domain" => domain_id}

      assert %{df_content: ^df_content} = Implementations.get_implementation!(id1)
      assert %{df_content: ^df_content} = Implementations.get_implementation!(id2)
    end

    test "return ids with valid df_content that include enriched text field", %{
      rule: %{name: rule_name},
      claims: claims
    } do
      template_content = [
        %{
          "fields" => [
            %{
              "name" => "enriched",
              "type" => "enriched_text",
              "label" => "enriched",
              "values" => nil,
              "widget" => "enriched_text",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      %{name: template_name} =
        CacheHelpers.insert_template(
          scope: "ri",
          content: template_content
        )

      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", template_name)
          |> Map.put("enriched", "foo")
        end)

      assert {:ok, %{ids: [_id1, _id2], errors: []}} = BulkLoad.bulk_load(imp, claims)
    end

    test "return ids with valid df_content that include hierarchy field", %{
      rule: %{name: rule_name},
      hierarchy_template_name: hierarchy_template_name,
      claims: claims,
      hierarchy: %{nodes: nodes}
    } do
      [%{key: key_node_1}, %{key: key_node_2} | _] = nodes

      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", hierarchy_template_name)
          |> Map.put("hierarchy_name_1", "children_1")
          |> Map.put("hierarchy_name_2", "father|children_1")
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(imp, claims)

      df_content = %{
        "hierarchy_name_1" => key_node_2,
        "hierarchy_name_2" => [key_node_1, key_node_2]
      }

      assert %{df_content: ^df_content} = Implementations.get_implementation!(id1)
      assert %{df_content: ^df_content} = Implementations.get_implementation!(id2)
    end

    test "return ids with valid df_content that include field with multiple values", %{
      rule: %{name: rule_name},
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
          scope: "ri",
          content: template_content
        )

      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", template_name)
          |> Map.put("multi_string", "a|b|c")
        end)

      assert {:ok, %{ids: [_id1, _id2], errors: []}} = BulkLoad.bulk_load(imp, claims)
    end

    test "return ids with valid df_content that include fixed values translated with single cardinality",
         %{
           claims: claims,
           domain: %{id: domain_id}
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "i18n",
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
          scope: "ri",
          content: template_content
        )

      CacheHelpers.put_i18n_message("es", %{message_id: "fields.i18n.one", definition: "uno"})

      [imp | _] = @valid_implementation

      imp =
        imp
        |> Map.put("template", template_name)
        |> Map.put("i18n", "uno")
        |> Map.put("domain_id", domain_id)

      assert {:ok, %{ids: [id1], errors: []}} = BulkLoad.bulk_load([imp], claims, false, "es")

      df_content = %{"i18n" => "one"}

      assert %{df_content: ^df_content} = Implementations.get_implementation!(id1)
    end

    test "return ids with valid df_content that include fixed values translated with multiple cardinality",
         %{
           claims: claims,
           domain: %{id: domain_id}
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "+",
              "label" => "i18n",
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
          scope: "ri",
          content: template_content
        )

      CacheHelpers.put_i18n_messages("es", [
        %{message_id: "fields.i18n.one", definition: "uno"},
        %{message_id: "fields.i18n.two", definition: "dos"}
      ])

      [imp | _] = @valid_implementation

      imp =
        imp
        |> Map.put("template", template_name)
        |> Map.put("i18n", "uno|dos")
        |> Map.put("domain_id", domain_id)

      assert {:ok, %{ids: [id1], errors: []}} = BulkLoad.bulk_load([imp], claims, false, "es")

      df_content = %{"i18n" => ["one", "two"]}

      assert %{df_content: ^df_content} = Implementations.get_implementation!(id1)
    end

    test "return error with df_content that include fixed values without i18n key and single cardinality",
         %{
           claims: claims,
           domain: %{id: domain_id}
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "i18n",
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
          scope: "ri",
          content: template_content
        )

      [imp | _] = @valid_implementation

      imp =
        imp
        |> Map.put("template", template_name)
        |> Map.put("i18n", "uno")
        |> Map.put("domain_id", domain_id)

      assert {:ok,
              %{
                errors: [
                  %{implementation_key: "boo", message: %{df_content: ["i18n: is invalid"]}}
                ]
              }}
    end

    test "return error with df_content that include fixed values without i18n key and multiple cardinality",
         %{
           claims: claims,
           domain: %{id: domain_id}
         } do
      template_content = [
        %{
          "fields" => [
            %{
              "cardinality" => "+",
              "label" => "i18n",
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
          scope: "ri",
          content: template_content
        )

      [imp | _] = @valid_implementation

      imp =
        imp
        |> Map.put("template", template_name)
        |> Map.put("i18n", "uno|dos")
        |> Map.put("domain_id", domain_id)

      assert {:ok, %{errors: [%{message: %{df_content: ["i18n: has an invalid entry"]}}]}} =
               BulkLoad.bulk_load([imp], claims, false, "es")
    end

    test "return error when rule not exist", %{
      rule: %{name: rule_name},
      claims: claims,
      domain: %{external_id: external_id}
    } do
      [imp1, imp2] = @valid_implementation

      imp1 =
        imp1
        |> Map.put("rule_name", rule_name)
        |> Map.put("domain_external_id", external_id)

      %{"implementation_key" => implementation_key} =
        imp2 =
        imp2
        |> Map.put("rule_name", "rule_not_exists")
        |> Map.put("domain_external_id", external_id)

      assert {:ok, %{ids: [id1], errors: [error]}} = BulkLoad.bulk_load([imp1, imp2], claims)

      assert %{implementation_key: "boo"} = Implementations.get_implementation!(id1)
      assert %{implementation_key: ^implementation_key, message: _} = error
    end

    test "return error when type_result is not valid", %{rule: %{name: rule_name}, claims: claims} do
      [imp1, imp2] =
        Enum.map(@valid_implementation, fn imp ->
          Map.put(imp, "rule_name", rule_name)
        end)

      %{"implementation_key" => implementation_key} =
        imp2 = Map.put(imp2, "result_type", "not_exists")

      assert {:ok, %{ids: [id1], errors: [error]}} = BulkLoad.bulk_load([imp1, imp2], claims)

      assert %{implementation_key: "boo"} = Implementations.get_implementation!(id1)

      assert %{implementation_key: ^implementation_key, message: %{result_type: ["is invalid"]}} =
               error
    end

    test "return errors with invalid valid df_content", %{
      rule: %{name: rule_name},
      claims: claims,
      template_name: template_name
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", template_name)
        end)

      assert {:ok, %{ids: [], errors: [_e1, _e2]}} = BulkLoad.bulk_load(imp, claims)
    end

    test "return error with hierarchy more than one nodes", %{
      rule: %{name: rule_name},
      hierarchy_template_name: hierarchy_template_name,
      claims: claims
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", hierarchy_template_name)
          |> Map.put("hierarchy_name_1", "children_2")
          |> Map.put("hierarchy_name_2", "children_2|children_2")
        end)

      assert {:ok, %{ids: [], errors: [_, _]}} = BulkLoad.bulk_load(imp, claims)
    end

    test "return errors when some field doesn't exist and not template defined", %{
      claims: claims,
      domain: %{external_id: external_id}
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("field_that_not_exists", "foo")
          |> Map.put("domain_external_id", external_id)
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{message: %{df_content: [_e1]}},
                  %{message: %{df_content: [_e2]}}
                ]
              }} = BulkLoad.bulk_load(imp, claims)
    end

    test "return errors when some template field doesn't exist", %{
      claims: claims,
      domain: %{external_id: external_id},
      template_name: template_name
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("field_that_not_exists", "foo")
          |> Map.put("domain_external_id", external_id)
          |> Map.put("template", template_name)
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{message: %{df_content: [_e1]}},
                  %{message: %{df_content: [_e2]}}
                ]
              }} = BulkLoad.bulk_load(imp, claims)
    end

    test "return errors when domain_external_id doesn't exist", %{
      claims: claims
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("domain_external_id", "foo")
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{message: %{"domain_external_id" => [_e1]}},
                  %{message: %{"domain_external_id" => [_e2]}}
                ]
              }} = BulkLoad.bulk_load(imp, claims)
    end

    test "return errors when template doesn't exist", %{
      claims: claims,
      domain: %{external_id: external_id}
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("domain_external_id", "foo")
          |> Map.put("domain_external_id", external_id)
          |> Map.put("template", "template_that_not_exists")
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{message: %{"template" => [_e1]}},
                  %{message: %{"template" => [_e2]}}
                ]
              }} = BulkLoad.bulk_load(imp, claims)
    end

    test "return errors when domain field of template doesn't exist", %{
      claims: claims,
      rule: %{name: rule_name}
    } do
      template_content = [
        %{
          "fields" => [
            %{
              "name" => "my_domain",
              "type" => "domain",
              "label" => "My domain",
              "values" => nil,
              "widget" => "dropdown",
              "default" => "",
              "cardinality" => "1",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      %{name: template_name} =
        CacheHelpers.insert_template(
          scope: "ri",
          content: template_content
        )

      imp =
        Enum.map(@valid_implementation, fn imp ->
          imp
          |> Map.put("rule_name", rule_name)
          |> Map.put("template", template_name)
          |> Map.put("my_domain", "domain_that_not_exists")
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{message: %{df_content: [_e1]}},
                  %{message: %{df_content: [_e2]}}
                ]
              }} = BulkLoad.bulk_load(imp, claims)
    end

    test "avoid mark as reindexable id unchanged implementations", %{
      rule: %{name: rule_name},
      claims: claims
    } do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          Map.put(imp, "rule_name", rule_name)
        end)

      assert {:ok, %{ids: [_, _] = ids, ids_to_reindex: ids_to_reindex, errors: []}} =
               BulkLoad.bulk_load(imp, claims)

      assert ids == ids_to_reindex
      assert {:ok, %{ids: ^ids, ids_to_reindex: [], errors: []}} = BulkLoad.bulk_load(imp, claims)
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
