defmodule TdDdWeb.GrantRequestStatusControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.Search.MockIndexWorker

  setup do
    start_supervised(MockIndexWorker)
    :ok
  end

  describe "create" do
    @tag authentication: [role: "user"]
    test "renders grant request when data is valid", %{conn: conn, claims: claims} do
      %{id: domain_id} = CacheHelpers.insert_domain()

      %{grant_request: grant_request, grant_request_id: grant_request_id} =
        insert(:grant_request_status,
          status: "approved",
          grant_request: build(:grant_request, domain_ids: [domain_id])
        )

      path = Routes.grant_request_status_path(conn, :create, grant_request)
      params = %{"status" => "processing", "reason" => "good reason"}

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> post(path, params)
               |> json_response(:forbidden)

      CacheHelpers.put_session_permissions(claims, domain_id, [:approve_grant_request])

      assert %{"data" => data} =
               conn
               |> post(path, params)
               |> json_response(:created)

      assert %{
               "id" => ^grant_request_id,
               "status" => "processing",
               "status_reason" => "good reason"
             } = data
    end

    @tag authentication: [role: "user"]
    test "user can cancel his own grant request if is pending or approved", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{grant_request: grant_request, grant_request_id: grant_request_id} =
        insert(:grant_request_status,
          status: "approved",
          grant_request:
            build(:grant_request,
              group: build(:grant_request_group, user_id: user_id)
            )
        )

      path = Routes.grant_request_status_path(conn, :create, grant_request)
      params = %{"status" => "cancelled"}

      assert %{"data" => data} =
               conn
               |> post(path, params)
               |> json_response(:created)

      assert %{
               "id" => ^grant_request_id,
               "status" => "cancelled"
             } = data
    end

    @tag authentication: [role: "user"]
    test "user without permission can not approve its own grant request", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{grant_request: grant_request} =
        insert(:grant_request_status,
          status: "pending",
          grant_request:
            build(:grant_request,
              group: build(:grant_request_group, user_id: user_id)
            )
        )

      path = Routes.grant_request_status_path(conn, :create, grant_request)
      params = %{"status" => "approved"}

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> post(path, params)
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "user can not cancel request if not in pending or approved status", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{grant_request: grant_request} =
        insert(:grant_request_status,
          status: "processing",
          grant_request:
            build(:grant_request,
              group: build(:grant_request_group, user_id: user_id)
            )
        )

      path = Routes.grant_request_status_path(conn, :create, grant_request)
      params = %{"status" => "cancelled"}

      assert %{"errors" => %{"status" => ["invalid status change"]}} =
               conn
               |> post(path, params)
               |> json_response(:unprocessable_entity)
    end
  end
end
