defmodule TdDdWeb.GrantRequestControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.Grants.GrantRequest

  @template_name "grant_request_controller_test_template"

  setup %{conn: conn} do
    CacheHelpers.insert_template(name: @template_name)
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all grant_requests", %{conn: conn} do
      grant_request_group = insert(:grant_request_group)

      assert %{"data" => []} =
               conn
               |> get(Routes.grant_request_group_request_path(conn, :index, grant_request_group))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "filters by status", %{conn: conn} do
      %{grant_request_id: id} = insert(:grant_request_status, status: "pending")
      insert(:grant_request_status, status: "approved", grant_request_id: id)

      params = %{"status" => "approved"}

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.grant_request_path(conn, :index, params))
               |> json_response(:ok)

      %{grant_request_id: id} = insert(:grant_request_status, status: "pending")
      params = %{"status" => "pending"}

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.grant_request_path(conn, :index, params))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "returns forbidden if user is not authorized", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> get(Routes.grant_request_path(conn, :index, %{}))
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "filters by domain permissions of an approver", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      create_acl_entry(user_id, domain_id, [:approve_grant_request])
      CacheHelpers.insert_grant_request_approver(user_id, domain_id)

      %{id: id} =
        insert(:grant_request, data_structure: build(:data_structure), domain_id: domain_id)

      insert(:grant_request, data_structure: build(:data_structure), domain_id: domain_id + 1)

      params = %{"action" => "approve"}

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.grant_request_path(conn, :index, params))
               |> json_response(:ok)
    end
  end

  describe "create grant_request" do
    @tag authentication: [role: "admin"]
    test "renders grant_request when data is valid", %{conn: conn} do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      %{id: data_structure_id} = insert(:data_structure)

      metadata = %{
        "list" => "one",
        "string" => "bar"
      }

      params = %{data_structure_id: data_structure_id, metadata: metadata, filters: %{}}

      assert %{"data" => data} =
               conn
               |> post(
                 Routes.grant_request_group_request_path(conn, :create, grant_request_group),
                 grant_request: params
               )
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "filters" => %{},
               "metadata" => ^metadata
             } = data
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "non-admin cannot create grant_request", %{conn: conn} do
      grant_request_group = insert(:grant_request_group)

      assert conn
             |> post(Routes.grant_request_group_request_path(conn, :create, grant_request_group),
               grant_request: %{}
             )
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant with invalid metadata", %{conn: conn} do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      %{id: data_structure_id} = insert(:data_structure)
      params = %{metadata: %{}, data_structure_id: data_structure_id}

      assert %{"errors" => errors} =
               conn
               |> post(
                 Routes.grant_request_group_request_path(conn, :create, grant_request_group),
                 grant_request: params
               )
               |> json_response(:unprocessable_entity)

      assert %{"metadata" => ["invalid content"]} = errors
    end

    @tag authentication: [role: "admin"]
    test "fails on invalid grant_request_group_id", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      params = %{metadata: %{}, data_structure_id: data_structure_id}

      assert %{"message" => "GrantRequestGroup"} =
               conn
               |> post(Routes.grant_request_group_request_path(conn, :create, 888),
                 grant_request: params
               )
               |> json_response(:not_found)
    end
  end

  describe "update grant_request" do
    setup [:create_grant_request]

    @tag authentication: [role: "admin"]
    test "renders grant_request when data is valid", %{
      conn: conn,
      grant_request: %GrantRequest{id: id} = grant_request
    } do
      params = %{filters: %{}, metadata: %{}}

      assert %{"data" => data} =
               conn
               |> put(Routes.grant_request_path(conn, :update, grant_request),
                 grant_request: params
               )
               |> json_response(:ok)

      assert %{"id" => ^id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "filters" => %{},
               "metadata" => %{}
             } = data
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user cannot update grant_request", %{
      conn: conn,
      grant_request: %GrantRequest{} = grant_request
    } do
      params = %{filters: %{}, metadata: %{}}

      assert conn
             |> put(Routes.grant_request_path(conn, :update, grant_request), grant_request: params)
             |> response(:forbidden)
    end
  end

  describe "delete grant_request" do
    setup [:create_grant_request]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant_request", %{conn: conn, grant_request: grant_request} do
      assert conn
             |> delete(Routes.grant_request_path(conn, :delete, grant_request))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.grant_request_path(conn, :show, grant_request))
      end
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user cannot delete grant_request", %{conn: conn, grant_request: grant_request} do
      assert conn
             |> delete(Routes.grant_request_path(conn, :delete, grant_request))
             |> response(:forbidden)
    end
  end

  defp create_grant_request(_) do
    grant_request = insert(:grant_request)
    %{grant_request: grant_request}
  end
end
