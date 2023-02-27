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

  setup do
    start_supervised!(TdDd.Search.MockIndexWorker)
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    domain = CacheHelpers.insert_domain()

    [rule: insert(:rule), claims: build(:claims), template_name: template_name, domain: domain]
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
                  %{message: %{"df_content" => [_e1]}},
                  %{message: %{"df_content" => [_e2]}}
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
          |> Map.put("my_domain", "domain_that_not_exists")
        end)

      assert {:ok,
              %{
                ids: [],
                errors: [
                  %{message: %{"df_content.my_domain" => [_e1]}},
                  %{message: %{"df_content.my_domain" => [_e2]}}
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
end
