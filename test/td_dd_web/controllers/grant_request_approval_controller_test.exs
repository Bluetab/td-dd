defmodule TdDdWeb.GrantRequestApprovalControllerTest do
  use TdDdWeb.ConnCase

  describe "create" do
    @tag authentication: [role: "user"]
    test "renders approval when data is valid", %{
      conn: conn,
      claims: %{user_id: user_id} = claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, domain_id: domain_id, role: "foo_role"}
      ])

      %{grant_request: grant_request} =
        insert(:grant_request_status,
          status: "pending",
          grant_request: build(:grant_request, domain_id: domain_id)
        )

      path = Routes.grant_request_approval_path(conn, :create, grant_request)
      params = %{"domain_id" => domain_id, "role" => "foo_role", "comment" => "foo"}

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
      assert %{"user" => %{"id" => ^user_id}, "domain" => %{"id" => ^domain_id}} = embedded
    end
  end
end
