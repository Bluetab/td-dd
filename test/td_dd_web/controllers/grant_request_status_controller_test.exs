defmodule TdDdWeb.GrantRequestStatusControllerTest do
  use TdDdWeb.ConnCase

  describe "create" do
    @tag authentication: [role: "user"]
    test "renders grant request when data is valid", %{conn: conn, claims: %{user_id: user_id}} do
      %{id: domain_id} = CacheHelpers.insert_domain()

      %{grant_request: grant_request, grant_request_id: grant_request_id} =
        insert(:grant_request_status,
          status: "approved",
          grant_request: build(:grant_request, domain_id: domain_id)
        )

      path = Routes.grant_request_status_path(conn, :create, grant_request)
      params = %{"status" => "processing"}

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> post(path, params)
               |> json_response(:forbidden)

      create_acl_entry(user_id, domain_id, [:approve_grant_request])

      assert %{"data" => data} =
               conn
               |> post(path, params)
               |> json_response(:created)

      assert %{"id" => ^grant_request_id, "status" => "processing"} = data
    end
  end
end
