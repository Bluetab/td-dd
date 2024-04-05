defmodule TdDd.Grants.ApprovalTest do
  use TdDd.DataCase

  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Repo

  @role "test role"

  setup do
    %{id: user_id, user_name: user_name} = CacheHelpers.insert_user()
    %{id: domain_id} = CacheHelpers.insert_domain()
    CacheHelpers.insert_acl(domain_id, @role, [user_id])
    %{id: grant_request_id, data_structure_id: requested_structure_id} = insert(:grant_request)

    [
      user_id: user_id,
      user_name: user_name,
      grant_request_id: grant_request_id,
      requested_structure_id: requested_structure_id,
      domain_id: domain_id
    ]
  end

  describe "GrantRequestApproval.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = GrantRequestApproval.changeset(%{})
      assert {_, [validation: :required]} = errors[:user_id]
      assert {_, [validation: :required]} = errors[:domain_ids]
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:grant_request_id]
      refute errors[:is_rejection]
    end

    test "validates current status is pending", %{user_id: user_id} do
      approval = %GrantRequestApproval{
        current_status: "approved",
        user_id: user_id,
        role: "approver",
        grant_request_id: 123
      }

      assert %{errors: errors} = GrantRequestApproval.changeset(approval, %{})

      assert {"is invalid", [validation: :inclusion, enum: ["pending"]]} = errors[:current_status]
    end

    test "validates user has role in domain", %{user_id: user_id} do
      params = %{"role" => @role}

      assert %{errors: errors} =
               %GrantRequestApproval{
                 grant_request_id: 123,
                 data_structure_id: 123,
                 user_id: user_id,
                 domain_ids: [0],
                 current_status: "pending"
               }
               |> GrantRequestApproval.changeset(params)

      assert {"invalid role", []} = errors[:user_id]
    end

    test "captures foreign key constraint on grant request", %{
      domain_id: domain_id,
      user_id: user_id
    } do
      params = %{"role" => @role}

      assert {:error, %{errors: errors}} =
               %GrantRequestApproval{
                 grant_request_id: 123,
                 data_structure_id: 123,
                 user_id: user_id,
                 domain_ids: [domain_id],
                 current_status: "pending"
               }
               |> GrantRequestApproval.changeset(params)
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
      grant_request_id: grant_request_id,
      requested_structure_id: requested_structure_id
    } do
      params = %{"role" => @role}

      assert {:ok, approval} =
               %GrantRequestApproval{
                 grant_request_id: grant_request_id,
                 data_structure_id: requested_structure_id,
                 user_id: user_id,
                 domain_ids: [domain_id],
                 current_status: "pending"
               }
               |> GrantRequestApproval.changeset(params)
               |> Repo.insert()

      assert %{
               domain_ids: [^domain_id],
               user_id: ^user_id,
               role: @role,
               grant_request_id: ^grant_request_id
             } = approval
    end

    test "inserts a valid changeset checking role by structure", %{user_id: user_id} do
      %{id: grant_request_id, domain_ids: domain_ids, data_structure_id: data_structure_id} =
        insert(:grant_request)

      CacheHelpers.insert_acl(data_structure_id, @role, [user_id], "structure")

      params = %{"role" => @role}

      assert {:ok, approval} =
               %GrantRequestApproval{
                 grant_request_id: grant_request_id,
                 data_structure_id: data_structure_id,
                 user_id: user_id,
                 domain_ids: domain_ids,
                 current_status: "pending"
               }
               |> GrantRequestApproval.changeset(params)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               role: @role,
               grant_request_id: ^grant_request_id
             } = approval
    end
  end
end
