defmodule TdDdWeb.Schema.MeTest do
  use TdDdWeb.ConnCase

  @current_roles """
  query CurrentRoles($domainId: ID, $permission: String) {
    currentRoles(domainId: $domainId, permission: $permission)
  }
  """

  describe "current_roles query" do
    @tag authentication: [role: "user"]
    test "returns user's roles", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: d1} = CacheHelpers.insert_domain()
      role_name = "approval_role"

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, domain_ids: [d1], role: "approval_role"}
      ])

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{"query" => @current_roles})
               |> json_response(:ok)

      assert data == %{"currentRoles" => [role_name]}
    end

    @tag authentication: [role: "user"]
    test "returns user's roles with permission argument", %{
      conn: conn,
      claims: %{user_id: user_id} = claims
    } do
      %{id: d1} = CacheHelpers.insert_domain()
      %{id: d2} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        approve_grant_request: [d1],
        view_grants: [d2]
      })

      role_name = "approval_role"

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, domain_ids: [d1], role: role_name}
      ])

      TdCache.UserCache.put_roles(user_id, %{role_name => [d1], "other_role" => [d2]})

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @current_roles,
                 "variables" => %{permission: "approve_grant_request"}
               })
               |> json_response(:ok)

      assert data == %{"currentRoles" => [role_name]}
    end

    @tag authentication: [role: "user"]
    test "returns user's roles with permission and domain argument", %{
      conn: conn,
      claims: %{user_id: user_id} = claims
    } do
      %{id: d1} = CacheHelpers.insert_domain()
      %{id: d2} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{approve_grant_request: [d1, d2]})

      role_name = "approval_role"

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, domain_ids: [d1], role: role_name},
        %{user_id: user_id, domain_ids: [d2], role: "other_role"}
      ])

      TdCache.UserCache.put_roles(user_id, %{role_name => [d1], "other_role" => [d2]})

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @current_roles,
                 "variables" => %{
                   permission: "approve_grant_request",
                   domainId: d1
                 }
               })
               |> json_response(:ok)

      assert data == %{"currentRoles" => [role_name]}
    end
  end
end
