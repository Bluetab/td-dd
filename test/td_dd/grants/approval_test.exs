defmodule TdDd.Grants.ApprovalTest do
  use TdDd.DataCase

  alias TdDd.Grants.Approval
  alias TdDd.Repo

  @role "test role"

  setup do
    %{id: user_id, user_name: user_name} = CacheHelpers.insert_user()
    %{id: domain_id} = CacheHelpers.insert_domain()
    CacheHelpers.insert_acl(domain_id, @role, [user_id])
    %{id: grant_request_id} = insert(:grant_request)

    [
      user_id: user_id,
      user_name: user_name,
      grant_request_id: grant_request_id,
      domain_id: domain_id
    ]
  end

  describe "Approval.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Approval.changeset(%{})
      assert {_, [validation: :required]} = errors[:user_id]
      assert {_, [validation: :required]} = errors[:domain_id]
      assert {_, [validation: :required]} = errors[:grant_request_id]
      refute errors[:is_rejection]
    end

    test "validates user has role in domain", %{user_id: user_id} do
      params = %{"domain_id" => 0, "role" => @role}

      assert %{errors: errors} =
               %Approval{grant_request_id: 123, user_id: user_id}
               |> Approval.changeset(params)

      assert {"invalid role", []} = errors[:user_id]
    end

    test "captures foreign key constraint on grant request", %{
      domain_id: domain_id,
      user_id: user_id
    } do
      params = %{"domain_id" => domain_id, "role" => @role}

      assert {:error, %{errors: errors}} =
               %Approval{grant_request_id: 123, user_id: user_id}
               |> Approval.changeset(params)
               |> Repo.insert()

      assert {_,
              [
                {:constraint, :foreign},
                {:constraint_name, "grant_request_approvals_grant_request_id_fkey"}
              ]} = errors[:grant_request_id]
    end

    test "inserts a valid changeset", %{
      domain_id: domain_id,
      user_id: user_id,
      grant_request_id: grant_request_id
    } do
      params = %{"domain_id" => domain_id, "role" => @role}

      assert {:ok, approval} =
               %Approval{grant_request_id: grant_request_id, user_id: user_id}
               |> Approval.changeset(params)
               |> Repo.insert()

      assert %{
               domain_id: ^domain_id,
               user_id: ^user_id,
               role: @role,
               grant_request_id: ^grant_request_id
             } = approval
    end
  end
end
