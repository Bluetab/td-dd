defmodule TdDdWeb.GrantRequestApprovalControllerTest do
  use TdDdWeb.ConnCase

  alias TdCore.Search.IndexWorker

  setup do
    IndexWorker.clear()

    :ok
  end

  describe "create" do
    @tag authentication: [role: "user"]
    test "renders approval when data is valid", %{
      conn: conn,
      claims: %{user_id: user_id} = claims
    } do
      IndexWorker.clear()
      %{id: domain_id} = CacheHelpers.insert_domain()

      %{grant_request: %{id: grant_request_id} = grant_request} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_ids: [domain_id])
        )

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, resource_id: domain_id, role: "foo_role"}
      ])

      path = Routes.grant_request_approval_path(conn, :create, grant_request)
      params = %{"role" => "foo_role", "comment" => "foo"}

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> post(path, approval: params)
               |> json_response(:forbidden)

      CacheHelpers.put_session_permissions(claims, domain_id, [:approve_grant_request])

      assert %{"data" => data} =
               conn
               |> post(path, approval: params)
               |> json_response(:created)

      assert %{"is_rejection" => false, "comment" => "foo", "_embedded" => embedded} = data
      assert %{"user" => %{"id" => ^user_id}} = embedded

      assert [{:reindex, :grant_requests, [^grant_request_id]}] = IndexWorker.calls()
    end

    @tag authentication: [role: "user"]
    test "user with approve_grant_request permission on requested structure can approve a grant request",
         %{
           conn: conn,
           claims: %{user_id: user_id} = claims
         } do
      IndexWorker.clear()
      %{id: domain_id} = CacheHelpers.insert_domain()

      %{
        grant_request:
          %{id: grant_request_id, data_structure_id: data_structure_id} = grant_request
      } =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_ids: [domain_id])
        )

      CacheHelpers.put_grant_request_approvers([
        %{
          user_id: user_id,
          resource_id: data_structure_id,
          role: "foo_role",
          resource_type: "structure"
        }
      ])

      path = Routes.grant_request_approval_path(conn, :create, grant_request)
      params = %{"role" => "foo_role", "comment" => "foo"}

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> post(path, approval: params)
               |> json_response(:forbidden)

      CacheHelpers.put_session_permissions(
        claims,
        data_structure_id,
        [:approve_grant_request],
        "structure"
      )

      assert %{"data" => data} =
               conn
               |> post(path, approval: params)
               |> json_response(:created)

      assert %{"is_rejection" => false, "comment" => "foo", "_embedded" => embedded} = data
      assert %{"user" => %{"id" => ^user_id}} = embedded

      assert [{:reindex, :grant_requests, [^grant_request_id]}] = IndexWorker.calls()
    end
  end
end
