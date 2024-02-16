defmodule TdDd.Grants.ApprovalRulesTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdDd.Grants.ApprovalRules

  @approval_role "approval_role"

  setup do
    %{id: user_id} = CacheHelpers.insert_user()
    %{id: domain_id} = CacheHelpers.insert_domain()
    CacheHelpers.insert_acl(domain_id, @approval_role, [user_id])

    [
      user_id: user_id,
      domain_id: domain_id,
      claims: build(:claims, user_id: user_id, role: @approval_role)
    ]
  end

  describe "get!/1" do
    test "returns the approval rule with given id" do
      %{id: id} = approval_rule = insert(:approval_rule)
      assert ApprovalRules.get!(id) <~> approval_rule
    end
  end

  describe "list_by_user/1" do
    test "return a list by specific user", %{user_id: user_id} do
      insert(:approval_rule)
      %{id: id_1} = insert(:approval_rule, user_id: user_id)
      %{id: id_2} = insert(:approval_rule, user_id: user_id)
      assert [%{id: ^id_1}, %{id: ^id_2}] = approval_list = ApprovalRules.list_by_user(user_id)
      assert 2 == Enum.count(approval_list)
    end
  end

  describe "create/2" do
    test "with valid data create a approval rule", %{
      claims: claims,
      user_id: user_id,
      domain_id: domain_id
    } do
      params = %{
        name: "rule_name",
        role: @approval_role,
        domain_ids: [domain_id],
        action: "approve",
        conditions: [%{field: "bar", operator: "is", values: ["foo"]}],
        comment: "bar"
      }

      assert {:ok, %{conditions: conditions} = approval_rule} =
               ApprovalRules.create(params, claims)

      assert %{user_id: ^user_id, domain_ids: [^domain_id], action: "approve", comment: "bar"} =
               approval_rule

      assert [%{field: "bar", operator: "is", values: ["foo"]}] = conditions
    end

    test "return error with invalid params", %{claims: claims} do
      assert {:error, %Ecto.Changeset{}} = ApprovalRules.create(%{}, claims)
    end
  end

  describe "update/2" do
    test "update approval rule", %{domain_id: domain_id, user_id: user_id} do
      %{id: id} =
        approval_rule = insert(:approval_rule, user_id: user_id, domain_ids: [domain_id])

      new_role = "new_role"
      CacheHelpers.insert_acl(domain_id, new_role, [user_id])
      claims = build(:claims, user_id: user_id, role: new_role)

      params = %{
        role: new_role,
        action: "reject",
        conditions: [%{field: "bar", operator: "is not", values: ["foo"]}],
        comment: "foo"
      }

      assert {:ok,
              %{
                id: ^id,
                action: "reject",
                role: ^new_role,
                comment: "foo",
                conditions: conditions
              }} = ApprovalRules.update(approval_rule, params, claims)

      assert [%{field: "bar", operator: "is not", values: ["foo"]}] = conditions
    end
  end

  describe "delete/1" do
    test "delete approval rule", %{domain_id: domain_id, user_id: user_id} do
      %{id: id} =
        approval_rule = insert(:approval_rule, user_id: user_id, domain_ids: [domain_id])

      assert {:ok, %{id: ^id}} = ApprovalRules.delete(approval_rule)

      assert_raise Ecto.NoResultsError, fn -> ApprovalRules.get!(id) end
    end
  end

  describe "get_rules_for_request/1" do
    test "filters ApprovalRule by request metadata field", %{domain_id: domain_id} do
      %{id: id} =
        insert(:approval_rule,
          role: @approval_role,
          domain_ids: [domain_id],
          conditions: [%{field: "request.foo", operator: "eq", value: "bar"}]
        )

      grant_request =
        insert(:grant_request,
          domain_ids: [domain_id],
          metadata: %{"foo" => "bar"},
          all_pending_roles: [@approval_role]
        )

      assert {_, rules} = ApprovalRules.get_rules_for_request(grant_request)
      assert [%{id: ^id}] = rules
    end

    test "rejects ApprovalRule by request metadata field", %{domain_id: domain_id} do
      insert(:approval_rule,
        role: @approval_role,
        domain_ids: [domain_id],
        conditions: [%{field: "request.foo", operator: "eq", value: "bar"}]
      )

      grant_request =
        insert(:grant_request,
          domain_ids: [domain_id],
          metadata: %{"foo" => "not bar"},
          all_pending_roles: [@approval_role]
        )

      assert {_, []} = ApprovalRules.get_rules_for_request(grant_request)
    end

    test "filters ApprovalRule by data_structure note field", %{domain_id: domain_id} do
      domain_ids = [domain_id]

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: domain_ids)
        )

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"foo" => "bar"},
        status: :published
      )

      data_structure =
        TdDd.Repo.preload(data_structure, current_version: [:published_note, :current_metadata])

      %{id: id} =
        insert(:approval_rule,
          role: @approval_role,
          domain_ids: domain_ids,
          conditions: [%{field: "note.foo", operator: "eq", value: "bar"}]
        )

      grant_request =
        insert(:grant_request,
          data_structure: data_structure,
          domain_ids: domain_ids,
          metadata: %{"foo" => "bar"},
          all_pending_roles: [@approval_role]
        )

      assert {_, rules} = ApprovalRules.get_rules_for_request(grant_request)
      assert [%{id: ^id}] = rules
    end

    test "filters ApprovalRule by data_structure metadata field", %{domain_id: domain_id} do
      domain_ids = [domain_id]

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          metadata: %{"foo" => "bar"},
          data_structure: build(:data_structure, domain_ids: domain_ids)
        )

      data_structure =
        TdDd.Repo.preload(data_structure, current_version: [:published_note, :current_metadata])

      %{id: id} =
        insert(:approval_rule,
          role: @approval_role,
          domain_ids: domain_ids,
          conditions: [%{field: "metadata.foo", operator: "eq", value: "bar"}]
        )

      grant_request =
        insert(:grant_request,
          data_structure: data_structure,
          domain_ids: domain_ids,
          all_pending_roles: [@approval_role]
        )

      assert {_, rules} = ApprovalRules.get_rules_for_request(grant_request)
      assert [%{id: ^id}] = rules
    end

    test "filters ApprovalRule by data_structure mutable metadata field", %{domain_id: domain_id} do
      domain_ids = [domain_id]

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: domain_ids)
        )

      insert(:structure_metadata,
        data_structure: data_structure,
        fields: %{"foo" => "bar"}
      )

      data_structure =
        TdDd.Repo.preload(data_structure, current_version: [:published_note, :current_metadata])

      %{id: id} =
        insert(:approval_rule,
          role: @approval_role,
          domain_ids: domain_ids,
          conditions: [%{field: "metadata.foo", operator: "eq", value: "bar"}]
        )

      grant_request =
        insert(:grant_request,
          data_structure: data_structure,
          domain_ids: domain_ids,
          all_pending_roles: [@approval_role]
        )

      assert {_, rules} = ApprovalRules.get_rules_for_request(grant_request)
      assert [%{id: ^id}] = rules
    end
  end
end
