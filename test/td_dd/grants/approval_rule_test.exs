defmodule TdDd.Grants.ApprovalRuleTest do
  use TdDd.DataCase

  alias TdDd.Grants.ApprovalRule

  @role "test role"
  @conditions [%{"field" => "foo", "operator" => "is", "values" => ["bar"]}]

  setup do
    %{id: user_id} = CacheHelpers.insert_user()
    %{id: domain_id} = CacheHelpers.insert_domain()
    CacheHelpers.insert_acl(domain_id, @role, [user_id])
    [user_id: user_id, domain_id: domain_id]
  end

  describe "ApprovalRule.changeset/2" do
    test "validate require fields" do
      assert %{errors: errors} = ApprovalRule.changeset(%{})
      assert {_, [validation: :required]} = errors[:name]
      assert {_, [validation: :required]} = errors[:user_id]
      assert {_, [validation: :required]} = errors[:domain_ids]
      assert {_, [validation: :required]} = errors[:role]
      assert {_, [validation: :required]} = errors[:action]
      assert {_, [validation: :required]} = errors[:conditions]
    end

    test "validates user has role in domain", %{user_id: user_id} do
      params = %{"role" => @role, "conditions" => @conditions}

      assert %{errors: errors} =
               %ApprovalRule{
                 name: "rule_name",
                 user_id: user_id,
                 domain_ids: [0],
                 action: "approve"
               }
               |> ApprovalRule.changeset(params)

      assert {"invalid role", []} = errors[:user_id]
    end

    test "inserts a valid changeset", %{user_id: user_id, domain_id: domain_id} do
      params = %{"role" => @role, "conditions" => @conditions}

      assert %{valid?: true} =
               %ApprovalRule{
                 name: "rule_name",
                 user_id: user_id,
                 domain_ids: [domain_id],
                 action: "approve"
               }
               |> ApprovalRule.changeset(params)
    end
  end
end
