defmodule TdDd.Grants.RequestsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Grants.Requests

  @template_name "grant_request_test_template"
  @valid_metadata %{"list" => "one", "string" => "bar"}

  setup do
    [claims: build(:claims)]
  end

  describe "grant_request_groups" do
    setup do
      [template: CacheHelpers.insert_template(name: @template_name)]
    end

    test "list_grant_request_groups/0 returns all grant_request_groups" do
      grant_request_group = insert(:grant_request_group)
      assert Requests.list_grant_request_groups() <|> [grant_request_group]
    end

    test "get_grant_request_group!/1 returns the grant_request_group with given id" do
      grant_request_group = insert(:grant_request_group)
      assert Requests.get_grant_request_group!(grant_request_group.id) <~> grant_request_group
    end

    test "create_grant_request_group/2 with valid data creates a grant_request_group" do
      %{id: data_structure_id} = insert(:data_structure)
      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [%{data_structure_id: data_structure_id, metadata: @valid_metadata}]
      }

      assert {:ok, %{group: group, statuses: statuses, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params, claims)

      assert %{
               type: @template_name,
               user_id: ^user_id
             } = group

      assert {1, nil} = statuses

      assert %{status: "pending"} = Repo.get_by!(GrantRequestStatus, grant_request_id: request_id)
    end

    test "creates grant_request_group requests" do
      %{id: ds_id_1} = insert(:data_structure)
      %{id: ds_id_2} = insert(:data_structure)

      requests = [
        %{
          data_structure_id: ds_id_1,
          filters: %{"foo" => "bar"},
          metadata: @valid_metadata
        },
        %{data_structure_id: ds_id_2, metadata: @valid_metadata}
      ]

      params = %{
        type: @template_name,
        requests: requests
      }

      assert {:ok, %{group: %{requests: requests}}} =
               Requests.create_grant_request_group(params, build(:claims))

      assert [
               %{
                 data_structure_id: ^ds_id_1,
                 filters: %{"foo" => "bar"},
                 metadata: @valid_metadata
               },
               %{data_structure_id: ^ds_id_2}
             ] = requests
    end

    test "create_grant_request_group/1 with invalid data returns error changeset" do
      invalid_params = %{type: nil}

      assert {:error, :group, %Ecto.Changeset{}, _} =
               Requests.create_grant_request_group(invalid_params, build(:claims))
    end

    test "delete_grant_request_group/1 deletes the grant_request_group" do
      grant_request_group = insert(:grant_request_group)

      assert {:ok, %GrantRequestGroup{}} =
               Requests.delete_grant_request_group(grant_request_group)

      assert_raise Ecto.NoResultsError, fn ->
        Requests.get_grant_request_group!(grant_request_group.id)
      end
    end
  end

  describe "list_grant_requests/2" do
    test "includes current status and status_reason and filters by status" do
      claims = build(:claims, role: "service")
      %{id: id} = insert(:grant_request)

      assert {:ok, grant_requests} = Requests.list_grant_requests(claims)
      assert [%{current_status: nil}] = grant_requests

      insert(:grant_request_status, grant_request_id: id, status: "earliest", reason: "reason1")

      assert {:ok, grant_requests} = Requests.list_grant_requests(claims)
      assert [%{current_status: "earliest", status_reason: "reason1"}] = grant_requests

      insert(:grant_request_status, grant_request_id: id, status: "latest", reason: "reason2")

      assert {:ok, grant_requests} = Requests.list_grant_requests(claims, %{status: "latest"})
      assert [%{current_status: "latest", status_reason: "reason2"}] = grant_requests

      assert {:ok, []} = Requests.list_grant_requests(claims, %{status: "earliest"})
    end

    test "includes domain_id and filters by domain_ids" do
      claims = build(:claims, role: "service")
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: data_structure_id} = insert(:data_structure)

      %{id: id} =
        insert(:grant_request, data_structure_id: data_structure_id, domain_id: domain_id)

      assert {:ok, grant_requests} = Requests.list_grant_requests(claims)
      assert [%{id: ^id, domain_id: ^domain_id}] = grant_requests

      assert {:ok, grant_requests} =
               Requests.list_grant_requests(claims, %{domain_ids: [domain_id]})

      assert [%{id: ^id}] = grant_requests

      assert {:ok, grant_requests} =
               Requests.list_grant_requests(claims, %{domain_ids: [domain_id + 1]})

      assert [] = grant_requests
    end

    test "filters by user_id" do
      %{user_id: user_id} = claims = build(:claims, role: "admin")

      %{id: id} = insert(:grant_request, group: build(:grant_request_group, user_id: user_id))
      insert(:grant_request)

      assert {:ok, [%{id: ^id}]} = Requests.list_grant_requests(claims, %{user_id: user_id})
    end

    test "filters by domain_ids if action is 'approve'" do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{user_id: user_id} = claims = build(:claims, role: "user")

      %{id: id} =
        insert(:grant_request,
          group: build(:grant_request_group, user_id: user_id),
          data_structure: build(:data_structure),
          domain_id: domain_id
        )

      assert {:ok, []} = Requests.list_grant_requests(claims, %{action: "approve"})

      CacheHelpers.insert_grant_request_approver(user_id, domain_id)

      assert {:ok, [%{id: ^id}]} = Requests.list_grant_requests(claims, %{action: "approve"})
    end

    test "filters by updated_since (status.inserted_at)", %{claims: claims} do
      ts = ~U[2021-02-03 04:05:06.123456Z]

      %{grant_request_id: id} = insert(:grant_request_status, inserted_at: ts)

      assert {:ok, []} =
               Requests.list_grant_requests(claims, %{updated_since: "2021-03-01T00:00:00Z"})

      assert {:ok, [%{id: ^id}]} =
               Requests.list_grant_requests(claims, %{updated_since: "2021-01-01T00:00:00Z"})
    end

    test "limits results", %{claims: claims} do
      for _ <- 1..3 do
        insert(:grant_request_status)
      end

      assert {:ok, res} = Requests.list_grant_requests(claims, %{})
      assert Enum.count(res) == 3

      assert {:ok, res} = Requests.list_grant_requests(claims, %{limit: 2})
      assert Enum.count(res) == 2
    end

    test "enriches pending_roles when action is approve", _ do
      %{id: d1} = CacheHelpers.insert_domain()
      %{id: d2} = CacheHelpers.insert_domain()
      %{id: d3} = CacheHelpers.insert_domain()
      %{user_id: default_approver} = build(:claims, role: "user")
      %{user_id: user_id} = claims = build(:claims, role: "user")

      CacheHelpers.insert_grant_request_approver(default_approver, d1, "approver1")
      CacheHelpers.insert_grant_request_approver(default_approver, d2, "approver2")
      CacheHelpers.insert_grant_request_approver(user_id, [d1, d2, d3], "approver2")

      %{grant_request: d1_gr} =
        insert(:grant_request_status,
          status: "approved",
          grant_request: build(:grant_request, domain_id: d1)
        )

      %{grant_request: %{id: pending_request_id} = d2_gr} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_id: d2)
        )

      %{grant_request: d2_gr_approved} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_id: d2)
        )

      %{grant_request: d3_gr} =
        insert(:grant_request_status,
          status: "rejected",
          grant_request: build(:grant_request, domain_id: d3)
        )

      insert(:grant_request_approval, domain_id: d1, role: "approver1", grant_request: d1_gr)
      insert(:grant_request_approval, domain_id: d2, role: "approver1", grant_request: d2_gr)

      insert(:grant_request_approval,
        domain_id: d2,
        role: "approver2",
        grant_request: d2_gr_approved
      )

      insert(:grant_request_approval,
        domain_id: d3,
        role: "approver1",
        is_rejection: true,
        grant_request: d3_gr
      )

      {:ok, grants} =
        Requests.list_grant_requests(claims, %{action: "approve", status: "pending"})

      assert [%GrantRequest{id: ^pending_request_id, pending_roles: ["approver2"]}] = grants
    end

    test "admin user sees all pending_roles with action approve", _ do
      %{id: d1} = CacheHelpers.insert_domain()
      %{id: d2} = CacheHelpers.insert_domain()
      %{user_id: default_approver} = build(:claims, role: "user")
      claims = build(:claims, role: "admin")

      CacheHelpers.insert_grant_request_approver(default_approver, d1, "approver1")
      CacheHelpers.insert_grant_request_approver(default_approver, d2, "approver2")

      %{grant_request: %{id: gr_id_1} = d1_gr} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_id: d1)
        )

      %{grant_request: %{id: gr_id_2}} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_id: d2)
        )

      insert(:grant_request_approval, domain_id: d1, role: "approver1", grant_request: d1_gr)

      {:ok, grants} =
        Requests.list_grant_requests(claims, %{action: "approve", status: "pending"})

      assert [
               %GrantRequest{id: ^gr_id_1, pending_roles: ["approver2"]},
               %GrantRequest{id: ^gr_id_2, pending_roles: ["approver1", "approver2"]}
             ] = grants
    end
  end

  describe "grant_requests" do
    test "get_grant_request!/1 returns the grant_request with given id", %{claims: claims} do
      grant_request = insert(:grant_request)
      assert Requests.get_grant_request!(grant_request.id, claims) <~> grant_request
    end

    test "delete_grant_request/1 deletes the grant_request", %{claims: claims} do
      grant_request = insert(:grant_request)
      assert {:ok, %GrantRequest{}} = Requests.delete_grant_request(grant_request)

      assert_raise Ecto.NoResultsError, fn ->
        Requests.get_grant_request!(grant_request.id, claims)
      end
    end

    test "enriches pending_roles", _ do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{user_id: default_approver} = build(:claims, role: "user")
      claims = build(:claims, role: "admin")

      CacheHelpers.insert_grant_request_approver(default_approver, domain_id, "approver1")
      CacheHelpers.insert_grant_request_approver(default_approver, domain_id, "approver2")

      %{grant_request: %{id: grant_request_id} = grant_request} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_id: domain_id)
        )

      insert(:grant_request_approval,
        domain_id: domain_id,
        role: "approver1",
        grant_request: grant_request
      )

      assert %GrantRequest{id: ^grant_request_id, pending_roles: ["approver2"]} =
               Requests.get_grant_request!(grant_request_id, claims)
    end
  end

  describe "Requests.create_approval/2" do
    setup :setup_grant_request

    test "approves grant request", %{
      claims: %{user_id: user_id} = claims,
      domain_id: domain_id,
      request: request
    } do
      CacheHelpers.insert_grant_request_approver(user_id, domain_id, "approver")
      params = %{domain_id: domain_id, role: "approver"}

      assert {:ok, %{approval: approval}} = Requests.create_approval(claims, request, params)
      assert %GrantRequestApproval{is_rejection: false, user: user, domain: domain} = approval
      assert %{id: ^user_id, user_name: _} = user
      assert %{id: ^domain_id, name: _} = domain
    end

    test "admin can approve a grant request without having the role", %{
      domain_id: domain_id,
      request: request
    } do
      %{user_id: user_id} = claims = build(:claims, role: "admin")
      params = %{domain_id: domain_id, role: "approver"}

      assert {:ok, %{approval: approval}} = Requests.create_approval(claims, request, params)

      assert %GrantRequestApproval{is_rejection: false, user_id: ^user_id, domain: domain} =
               approval

      assert %{id: ^domain_id, name: _} = domain
    end

    test "returns error if user is not an approver", %{
      domain_id: domain_id,
      request: request
    } do
      claims = build(:claims, role: "user")
      params = %{domain_id: domain_id, role: "not_approver"}
      assert {:error, :approval, _, _} = Requests.create_approval(claims, request, params)
    end

    test "inserts a rejected status the approval is rejected", %{
      claims: %{user_id: user_id} = claims,
      domain_id: domain_id,
      request: request
    } do
      CacheHelpers.insert_grant_request_approver(user_id, domain_id, "rejector")
      params = %{domain_id: domain_id, role: "rejector", is_rejection: true, comment: "foo"}

      assert {:ok, %{status: status}} = Requests.create_approval(claims, request, params)
      assert %GrantRequestStatus{status: "rejected"} = status
    end

    test "inserts a approved status the approval is approved", %{
      claims: %{user_id: user_id} = claims,
      domain_id: domain_id,
      request: request
    } do
      CacheHelpers.insert_grant_request_approver(user_id, domain_id, "approver1")
      CacheHelpers.insert_grant_request_approver(user_id, domain_id, "approver2")

      params = %{domain_id: domain_id, role: "approver1"}
      assert {:ok, %{status: nil}} = Requests.create_approval(claims, request, params)

      params = %{domain_id: domain_id, role: "approver2"}
      assert {:ok, %{status: status}} = Requests.create_approval(claims, request, params)
      assert %GrantRequestStatus{status: "approved"} = status
    end
  end

  defp setup_grant_request(%{claims: %{user_id: user_id}}) do
    %{id: parent_id} = CacheHelpers.insert_domain()
    %{id: domain_id} = CacheHelpers.insert_domain(%{parent_ids: [parent_id]})
    CacheHelpers.insert_user(%{user_id: user_id})

    [domain_id: domain_id, request: insert(:grant_request, current_status: "pending")]
  end
end
