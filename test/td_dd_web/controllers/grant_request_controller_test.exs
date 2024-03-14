defmodule TdDdWeb.GrantRequestControllerTest do
  use TdDdWeb.ConnCase

  alias TdCore.Search.IndexWorkerMock

  @moduletag sandbox: :shared
  @template_name "grant_request_controller_test_template"

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
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
          status: "approved",
          reason: "because"
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
                 "status_reason" => "because",
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
      claims: %{user_id: user_id} = claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      CacheHelpers.put_session_permissions(claims, domain_id, [:approve_grant_request])

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, resource_id: domain_id, role: "approver"}
      ])

      %{id: id} =
        insert(:grant_request, data_structure: build(:data_structure), domain_ids: [domain_id])

      insert(:grant_request, data_structure: build(:data_structure), domain_ids: [domain_id + 1])

      params = %{"action" => "approve"}

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.grant_request_path(conn, :index, params))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "lists current user own requests with parameter user => me", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} =
        insert(:grant_request,
          group: insert(:grant_request_group, user_id: user_id)
        )

      insert(:grant_request)

      params = %{"user" => "me"}

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.grant_request_path(conn, :index, params))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "lists requests where user has created_by_id with parameter user => me", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} =
        insert(:grant_request,
          group: insert(:grant_request_group, created_by_id: user_id)
        )

      insert(:grant_request)

      params = %{"user" => "me"}

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.grant_request_path(conn, :index, params))
               |> json_response(:ok)
    end
  end

  describe "show grant_request" do
    @tag authentication: [role: "user"]
    test "user without permission can show its own grant_request", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} =
        insert(:grant_request,
          group: insert(:grant_request_group, user_id: user_id)
        )

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permission can show grant_request created_by user", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} =
        insert(:grant_request,
          group: insert(:grant_request_group, created_by_id: user_id)
        )

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "_embedded is populated", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{
        data_structure_id: data_structure_id,
        data_structure: %{external_id: external_id},
        name: name
      } = insert(:data_structure_version)

      %{id: id} =
        insert(:grant_request,
          data_structure_id: data_structure_id,
          group:
            insert(:grant_request_group,
              user_id: user_id,
              created_by_id: user_id
            )
        )

      assert %{"data" => %{"id" => ^id, "_embedded" => embedded}} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"data_structure" => data_structure, "group" => group} = embedded

      assert %{
               "id" => ^data_structure_id,
               "external_id" => ^external_id,
               "name" => ^name
             } = data_structure

      assert %{"type" => _, "id" => _, "_embedded" => embedded} = group

      assert %{
               "user" => %{"id" => ^user_id, "user_name" => _, "full_name" => _},
               "created_by" => %{"id" => ^user_id, "user_name" => _, "full_name" => _}
             } = embedded
    end

    @tag authentication: [role: "user"]
    test "user with permission can show grant_request", %{
      conn: conn,
      claims: %{user_id: user_id} = claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      CacheHelpers.put_session_permissions(claims, domain_id, [:approve_grant_request])

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, resource_id: domain_id, role: "approver"}
      ])

      %{id: id} =
        insert(:grant_request, data_structure: build(:data_structure), domain_ids: [domain_id])

      assert %{"data" => %{"id" => ^id, "pending_roles" => ["approver"]}} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permission cannot show grant_request of other user", %{conn: conn} do
      %{id: id} = insert(:grant_request)

      assert conn
             |> get(Routes.grant_request_path(conn, :show, id))
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "user with permission on a grant requested structure can show grant_request", %{
      conn: conn,
      claims: %{user_id: user_id} = claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: structure_id} = data_structure = insert(:data_structure, domain_ids: [domain_id])
      %{id: id} = insert(:grant_request, data_structure: data_structure)

      CacheHelpers.put_grant_request_approvers([
        %{
          user_id: user_id,
          resource_id: structure_id,
          resource_type: "structure",
          role: "approver"
        }
      ])

      assert conn
             |> get(Routes.grant_request_path(conn, :show, id))
             |> json_response(:forbidden)

      CacheHelpers.put_session_permissions(
        claims,
        structure_id,
        [:approve_grant_request],
        "structure"
      )

      assert %{"data" => %{"id" => ^id, "pending_roles" => ["approver"]}} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permission on a grant requested structure can approve or reject a grant_request of type removal",
         %{
           conn: conn,
           claims: %{user_id: user_id} = claims
         } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: structure_id} = insert(:data_structure, domain_ids: [domain_id])
      grant = insert(:grant, data_structure_id: structure_id)

      %{id: id} =
        insert(:grant_request,
          request_type: :grant_removal,
          grant: grant
        )

      CacheHelpers.put_grant_request_approvers([
        %{
          user_id: user_id,
          resource_id: structure_id,
          resource_type: "structure",
          role: "approver"
        }
      ])

      CacheHelpers.put_session_permissions(
        claims,
        structure_id,
        [:approve_grant_request],
        "structure"
      )

      assert %{"data" => %{"id" => ^id, "pending_roles" => ["approver"]}} =
               conn
               |> get(Routes.grant_request_path(conn, :show, id))
               |> json_response(:ok)
    end
  end

  describe "delete grant_request" do
    setup [:create_grant_request]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant_request", %{
      conn: conn,
      grant_request: %{id: grant_request_id} = grant_request
    } do
      IndexWorkerMock.clear()

      assert conn
             |> delete(Routes.grant_request_path(conn, :delete, grant_request))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.grant_request_path(conn, :show, grant_request))
      end

      assert [{:delete, :grant_requests, [^grant_request_id]}] = IndexWorkerMock.calls()
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user cannot delete grant_request", %{
      conn: conn,
      grant_request: grant_request
    } do
      IndexWorkerMock.clear()

      assert conn
             |> delete(Routes.grant_request_path(conn, :delete, grant_request))
             |> response(:forbidden)

      assert [] = IndexWorkerMock.calls()
    end
  end

  defp create_grant_request(_) do
    grant_request = insert(:grant_request)
    %{grant_request: grant_request}
  end
end
