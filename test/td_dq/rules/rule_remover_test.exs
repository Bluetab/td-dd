defmodule TdDq.Rules.RuleRemoverTest do
  use TdDd.DataCase

  alias TdCache.ConceptCache
  alias TdDq.Rules.RuleRemover

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDq.Cache.RuleLoader)
    %{id: domain_id} = CacheHelpers.insert_domain()
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")

    [domain_id: domain_id, template_name: template_name]
  end

  describe "archive_inactive_rules/0" do
    test "returns :ok when ConceptCache.active_ids returns empty list" do
      ConceptCache.put(%{id: 123, name: "foo"})
      ConceptCache.put(%{id: 456, name: "bar"})
      ConceptCache.delete(123)
      ConceptCache.delete(456)

      assert :ok = RuleRemover.archive_inactive_rules()
    end

    test "returns :ok when ConceptCache.active_ids returns error" do
      assert :ok = RuleRemover.archive_inactive_rules()
    end

    test "soft deletes rules associated with deleted business concepts", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      active_bc_id = System.unique_integer([:positive])
      deleted_bc_id = System.unique_integer([:positive])

      ConceptCache.put(%{id: active_bc_id, name: "Active Concept"})

      active_rule =
        insert(:rule,
          business_concept_id: active_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      deleted_rule =
        insert(:rule,
          business_concept_id: deleted_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      assert is_nil(Repo.reload(active_rule).deleted_at)
      assert is_nil(Repo.reload(deleted_rule).deleted_at)

      assert :ok = RuleRemover.archive_inactive_rules()

      assert Repo.reload(active_rule).deleted_at == nil
      refute Repo.reload(deleted_rule).deleted_at == nil
    end

    test "soft deletes implementations of rules associated with deleted business concepts", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      active_bc_id = System.unique_integer([:positive])
      deleted_bc_id = System.unique_integer([:positive])

      ConceptCache.put(%{id: active_bc_id, name: "Active Concept"})

      active_rule =
        insert(:rule,
          business_concept_id: active_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      deleted_rule =
        insert(:rule,
          business_concept_id: deleted_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      active_impl = insert(:implementation, rule: active_rule, domain_id: domain_id)
      deleted_impl = insert(:implementation, rule: deleted_rule, domain_id: domain_id)

      assert is_nil(Repo.reload(active_impl).deleted_at)
      assert is_nil(Repo.reload(deleted_impl).deleted_at)

      assert :ok = RuleRemover.archive_inactive_rules()

      assert Repo.reload(active_impl).deleted_at == nil
      refute Repo.reload(deleted_impl).deleted_at == nil
      assert Repo.reload(deleted_impl).status == :deprecated
    end

    test "soft deletes both rules and implementations", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      active_bc_id = System.unique_integer([:positive])
      deleted_bc_id_1 = System.unique_integer([:positive])
      deleted_bc_id_2 = System.unique_integer([:positive])

      ConceptCache.put(%{id: active_bc_id, name: "Active Concept"})

      active_rule =
        insert(:rule,
          business_concept_id: active_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      deleted_rule_1 =
        insert(:rule,
          business_concept_id: deleted_bc_id_1,
          df_name: template_name,
          domain_id: domain_id
        )

      deleted_rule_2 =
        insert(:rule,
          business_concept_id: deleted_bc_id_2,
          df_name: template_name,
          domain_id: domain_id
        )

      impl_active = insert(:implementation, rule: active_rule, domain_id: domain_id)
      impl_1 = insert(:implementation, rule: deleted_rule_1, domain_id: domain_id)
      impl_2 = insert(:implementation, rule: deleted_rule_2, domain_id: domain_id)

      assert :ok = RuleRemover.archive_inactive_rules()

      assert Repo.reload(active_rule).deleted_at == nil
      refute Repo.reload(deleted_rule_1).deleted_at == nil
      refute Repo.reload(deleted_rule_2).deleted_at == nil
      assert Repo.reload(impl_active).deleted_at == nil
      refute Repo.reload(impl_1).deleted_at == nil
      refute Repo.reload(impl_2).deleted_at == nil
      assert Repo.reload(impl_1).status == :deprecated
      assert Repo.reload(impl_2).status == :deprecated
    end

    test "does not delete rules without business_concept_id", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      rule_without_bc =
        insert(:rule,
          business_concept_id: nil,
          df_name: template_name,
          domain_id: domain_id
        )

      assert :ok = RuleRemover.archive_inactive_rules()
      assert Repo.reload(rule_without_bc).deleted_at == nil
    end

    test "does not delete already deleted rules", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      deleted_bc_id = System.unique_integer([:positive])

      already_deleted_rule =
        insert(:rule,
          business_concept_id: deleted_bc_id,
          df_name: template_name,
          domain_id: domain_id,
          deleted_at: DateTime.utc_now()
        )

      assert :ok = RuleRemover.archive_inactive_rules()

      assert Repo.reload(already_deleted_rule).deleted_at != nil
    end

    test "soft deletes multiple rules and implementations", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      active_bc_id = System.unique_integer([:positive])
      deleted_bc_id = System.unique_integer([:positive])

      # Only put the active concept in cache (deleted concept is not in cache)
      ConceptCache.put(%{id: active_bc_id, name: "Active Concept"})

      active_rule =
        insert(:rule,
          business_concept_id: active_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      deleted_rule =
        insert(:rule,
          business_concept_id: deleted_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      impl1 = insert(:implementation, rule: deleted_rule, domain_id: domain_id)
      impl2 = insert(:implementation, rule: deleted_rule, domain_id: domain_id)
      impl3 = insert(:implementation, rule: deleted_rule, domain_id: domain_id)

      assert :ok = RuleRemover.archive_inactive_rules()

      assert Repo.reload(active_rule).deleted_at == nil

      refute Repo.reload(deleted_rule).deleted_at == nil
      refute Repo.reload(impl1).deleted_at == nil
      refute Repo.reload(impl2).deleted_at == nil
      refute Repo.reload(impl3).deleted_at == nil
      assert Repo.reload(impl1).status == :deprecated
      assert Repo.reload(impl2).status == :deprecated
      assert Repo.reload(impl3).status == :deprecated
    end

    test "does not delete when all concepts are active", %{
      domain_id: domain_id,
      template_name: template_name
    } do
      active_bc_id = System.unique_integer([:positive])

      ConceptCache.put(%{id: active_bc_id, name: "Active"})

      active_rule =
        insert(:rule,
          business_concept_id: active_bc_id,
          df_name: template_name,
          domain_id: domain_id
        )

      active_impl = insert(:implementation, rule: active_rule, domain_id: domain_id)

      assert :ok = RuleRemover.archive_inactive_rules()

      assert Repo.reload(active_rule).deleted_at == nil
      assert Repo.reload(active_impl).deleted_at == nil
    end
  end
end
