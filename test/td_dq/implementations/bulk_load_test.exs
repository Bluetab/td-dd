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

    [rule: insert(:rule), claims: build(:dq_claims), template_name: template_name, domain: domain]
  end

  describe "bulk_load/2" do
    @tag authentication: [role: "admin"]

    test "return ids from inserted implementations", %{rule: %{name: rule_name}, claims: claims} do
      imp =
        Enum.map(@valid_implementation, fn imp ->
          Map.put(imp, "rule_name", rule_name)
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(imp, claims)

      assert %{implementation_key: "boo"} = Implementations.get_implementation!(id1)
      assert %{implementation_key: "bar"} = Implementations.get_implementation!(id2)
    end

    test "return ids from inserted implementations without rule", %{claims: claims} do
      %{external_id: domain_external_id} = CacheHelpers.insert_domain()

      imp =
        Enum.map(@valid_implementation, fn imp ->
          Map.put(imp, "domain_external_id", domain_external_id)
        end)

      assert {:ok, %{ids: [id1, id2], errors: []}} = BulkLoad.bulk_load(imp, claims)

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
  end
end
