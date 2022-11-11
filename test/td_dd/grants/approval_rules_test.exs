defmodule TdDd.Grants.ApprovalRulesTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdDd.Grants.ApprovalRule
  alias TdDd.Grants.ApprovalRules
  alias TdDd.Grants.Condition

  @role "role1"

  setup do
    %{id: user_id} = CacheHelpers.insert_user()
    %{id: domain_id} = CacheHelpers.insert_domain()
    CacheHelpers.insert_acl(domain_id, @role, [user_id])

    [
      user_id: user_id,
      domain_id: domain_id,
      claims: build(:claims, user_id: user_id, role: @role)
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
        role: @role,
        domain_ids: [domain_id],
        action: "approve",
        conditions: [%{field: "bar", operator: "is", value: "foo"}],
        comment: "bar"
      }

      assert {:ok, %ApprovalRule{conditions: approval_condition} = approval_rule} =
               ApprovalRules.create(params, claims)

      assert %{user_id: ^user_id, domain_ids: [^domain_id], action: "approve", comment: "bar"} =
               approval_rule

      assert [%Condition{field: "bar", operator: "is", value: "foo"}] = approval_condition
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
        conditions: [%{field: "bar", operator: "is not", value: "foo"}],
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

      assert [%Condition{field: "bar", operator: "is not", value: "foo"}] = conditions
    end
  end

  describe "delete/1" do
    test "delete approval rule", %{domain_id: domain_id, user_id: user_id} do
      %{id: id} =
        approval_rule = insert(:approval_rule, user_id: user_id, domain_ids: [domain_id])

      assert {:ok, %ApprovalRule{id: ^id}} = ApprovalRules.delete(approval_rule)

      assert_raise Ecto.NoResultsError, fn -> ApprovalRules.get!(id) end
    end
  end
end
