defmodule TdDdWeb.GrantRequestControllerTest do
  use TdDdWeb.ConnCase

  @template_name "grant_request_controller_test_template"

  setup do
    CacheHelpers.insert_template(name: @template_name)
    :ok
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all grant requests", %{conn: conn} do
      %{id: user_id} = CacheHelpers.insert_user()

      %{
        data_structure_id: data_structure_id,
        data_structure: %{external_id: external_id},
        metadata: structure_metadata,
        type: type,
        name: name
      } = insert(:data_structure_version)

      %{grant_request: %{id: id, metadata: request_metadata}} =
        insert(:grant_request_status,
          grant_request:
            build(:grant_request,
              group: build(:grant_request_group, user_id: user_id),
              data_structure_id: data_structure_id
            ),
          status: "approved"
        )

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_path(conn, :index))
               |> json_response(:ok)

      assert [
               %{
                 "id" => ^id,
                 "metadata" => ^request_metadata,
                 "filters" => _,
                 "inserted_at" => _,
                 "status" => "approved",
                 "_embedded" => embedded
               }
             ] = data

      assert %{"data_structure" => data_structure, "group" => group} = embedded

      assert %{
               "id" => ^data_structure_id,
               "external_id" => ^external_id,
               "name" => ^name,
               "type" => ^type,
               "metadata" => ^structure_metadata
             } = data_structure

      assert %{"type" => _, "id" => _, "_embedded" => embedded} = group
      assert %{"user" => %{"id" => ^user_id, "user_name" => _, "full_name" => _}} = embedded
    end

    @tag authentication: [role: "admin"]
    test "lists grant requests of a given group", %{conn: conn} do
      group = insert(:grant_request_group)

      assert %{"data" => []} =
               conn
               |> get(Routes.grant_request_group_request_path(conn, :index, group))
               |> json_response(:ok)

      %{group: group} = insert(:grant_request)

      assert %{"data" => [_]} =
               conn
               |> get(Routes.grant_request_group_request_path(conn, :index, group))
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
