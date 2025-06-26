defmodule TdDd.Cache.ImplementationLoaderTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.ImplementationCache
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Implementations
  alias TdDq.Rules

  describe "ImplementationLoader.cache_implementations/2" do
    setup do
      TdCache.Redix.del!()
      start_supervised!(TdDd.Search.StructureEnricher)
      start_supervised(TdDq.Cache.RuleLoader)
      :ok
    end

    @tag sandbox: :shared
    test "encodes and puts cache entries with rule_results" do
      %{id: id} = implementation = insert(:implementation)
      ts = DateTime.utc_now()
      insert(:rule_result, implementation: implementation, date: DateTime.add(ts, -10))

      %{
        errors: errors,
        records: records,
        result: expected_result
      } =
        insert(:rule_result,
          implementation: implementation,
          date: ts,
          errors: 6,
          records: 6,
          result: 100.00
        )

      assert %{ok: 1} =
               [id]
               |> ImplementationLoader.cache_implementations()
               |> Enum.frequencies_by(&elem(&1, 0))

      string_date =
        ts
        |> DateTime.truncate(:second)
        |> DateTime.to_string()

      assert {:ok,
              %{
                execution_result_info: %{
                  errors: ^errors,
                  records: ^records,
                  result: result,
                  date: ^string_date,
                  result_text: "quality_result.over_goal"
                }
              }} = ImplementationCache.get(id)

      assert Decimal.eq?(expected_result, result)
    end

    @tag sandbox: :shared
    test "encodes and puts cache entries with rule" do
      %{id: id, implementation_ref: implementation_ref, rule: %{id: rule_id, name: rule_name}} =
        insert(:implementation)

      assert %{ok: 1} =
               [implementation_ref]
               |> ImplementationLoader.cache_implementations()
               |> Enum.frequencies_by(&elem(&1, 0))

      assert {:ok,
              %{
                rule: %{
                  id: ^rule_id,
                  name: ^rule_name
                }
              }} = ImplementationCache.get(id)
    end

    @tag sandbox: :shared
    test "add relations between implementation_id and implementation_ref" do
      %{id: impl_id1} = impl1 = insert(:implementation)
      %{id: impl_id2} = impl2 = insert(:implementation)
      %{id: impl_id3} = impl3 = insert(:implementation, implementation_ref: impl_id2)
      %{id: impl_id4} = impl4 = insert(:implementation)
      impl5 = insert(:implementation, implementation_ref: impl_id4)

      [impl1, impl2, impl3, impl4, impl5]
      |> Enum.map(&CacheHelpers.put_implementation(&1))

      [impl_id1, impl_id3, impl_id4]
      |> Enum.map(&CacheHelpers.insert_link(&1, "implementation", "foo", nil))

      assert 3 == ImplementationLoader.do_migration_implementation_id_to_implementation_ref()

      result =
        ImplementationCache.get_relation_impl_id_and_impl_ref()
        |> Enum.map(&String.to_integer(&1))

      assert [impl_id1, impl_id1, impl_id3, impl_id2, impl_id4, impl_id4] ||| result
    end

    @tag sandbox: :shared
    test "update cache when the domain changes without rule" do
      claims = build(:claims)
      %{id: old_domain_id} = CacheHelpers.insert_domain()
      %{id: new_domain_id} = CacheHelpers.insert_domain()

      %{id: id, implementation_ref: implementation_ref} =
        implementation =
        insert(:implementation,
          status: "draft",
          domain_id: old_domain_id
        )

      assert [ok: [11, 1, 1, 0]] =
               ImplementationLoader.cache_implementations([implementation_ref])

      %{id: concept_id} = CacheHelpers.insert_concept()

      CacheHelpers.insert_link(
        implementation_ref,
        "implementation_ref",
        "business_concept",
        concept_id
      )

      assert {:ok,
              %{
                domain_id: ^old_domain_id
              }} = ImplementationCache.get(id)

      update_attrs =
        string_params_for(:implementation, domain_id: new_domain_id)

      Implementations.update_implementation(
        implementation,
        update_attrs,
        claims
      )

      assert {:ok,
              %{
                domain_id: ^new_domain_id
              }} = ImplementationCache.get(id)
    end

    @tag sandbox: :shared
    test "update cache when the domain changes with rule" do
      claims = build(:claims)
      %{id: old_domain_id} = old_domain = CacheHelpers.insert_domain()
      %{id: new_domain_id} = CacheHelpers.insert_domain()

      %{id: rule_id} =
        rule = insert(:rule, domain_id: old_domain_id, domain: old_domain)

      %{id: id, implementation_ref: implementation_ref} =
        insert(:implementation,
          status: "draft",
          rule: rule,
          rule_id: rule_id,
          domain_id: old_domain_id,
          domain: old_domain
        )

      assert [ok: [11, 1, 1, 0]] =
               ImplementationLoader.cache_implementations([implementation_ref])

      %{id: concept_id} = CacheHelpers.insert_concept()

      CacheHelpers.insert_link(
        implementation_ref,
        "implementation_ref",
        "business_concept",
        concept_id
      )

      assert {:ok,
              %{
                domain_id: ^old_domain_id
              }} = ImplementationCache.get(id)

      params = %{"domain_id" => new_domain_id}

      assert {:ok, %{rule: %{domain_id: ^new_domain_id}}} =
               Rules.update_rule(rule, params, claims)

      assert {:ok,
              %{
                domain_id: ^new_domain_id
              }} = ImplementationCache.get(id)
    end
  end

  @tag sandbox: :shared
  test "update cache when the domain when move to rule" do
    claims = build(:claims)
    %{id: old_domain_id} = old_domain = CacheHelpers.insert_domain()
    %{id: new_domain_id} = CacheHelpers.insert_domain()

    %{id: rule_id} = insert(:rule, domain_id: new_domain_id, domain: new_domain_id)

    %{id: id, implementation_ref: implementation_ref} =
      implementation =
      insert(:implementation,
        status: "draft",
        domain_id: old_domain_id,
        domain: old_domain
      )

    assert [ok: [11, 1, 1, 0]] =
             ImplementationLoader.cache_implementations([implementation_ref])

    %{id: concept_id} = CacheHelpers.insert_concept()

    CacheHelpers.insert_link(
      implementation_ref,
      "implementation_ref",
      "business_concept",
      concept_id
    )

    assert {:ok, %{domain_id: ^old_domain_id}} = ImplementationCache.get(id)

    params = %{"rule_id" => rule_id}

    Implementations.update_implementation(
      implementation,
      params,
      claims
    )

    assert {:ok,
            %{
              domain_id: ^new_domain_id
            }} = ImplementationCache.get(id)
  end
end
