defmodule TdDdWeb.GrantRequestBulkApprovalControllerTest do
  use TdDdWeb.ConnCase

  import Mox
  import TdDd.TestOperators

  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.Hierarchy

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  setup :verify_on_exit!

  describe "create" do
    setup :create_grant_request

    @tag authentication: [role: "admin"]
    test "admin can create rejected approvals using multiple ids", %{
      conn: conn,
      grant_request: %{user: user}
    } do
      IndexWorkerMock.clear()
      %{id: grant_request1_id} = grant_request1 = create_grant_request(user, [])
      %{id: grant_request2_id} = grant_request2 = create_grant_request(user, [])
      %{id: grant_request3_id} = grant_request3 = create_grant_request(user, [])

      grant_requests_ids = [
        to_string(grant_request1_id),
        to_string(grant_request2_id),
        to_string(grant_request3_id)
      ]

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grant_requests/_search", %{query: query, size: _}, _ ->
        assert %{bool: %{must: %{terms: %{"id" => query_grant_requests_ids}}}} = query
        assert grant_requests_ids ||| query_grant_requests_ids
        SearchHelpers.hits_response([grant_request1, grant_request2, grant_request3])
      end)

      params = %{
        filters: %{id: grant_requests_ids},
        role: "Approval Role",
        comment: "Approval Comment",
        is_rejection: true
      }

      assert %{"data" => [first_approval | _]} =
               conn
               |> post(Routes.grant_request_bulk_approval_path(conn, :create, params))
               |> json_response(:created)

      assert %{
               "comment" => params.comment,
               "is_rejection" => params.is_rejection,
               "role" => params.role
             } == Map.take(first_approval, ["comment", "is_rejection", "role"])

      assert [
               {:reindex, :grant_requests,
                [^grant_request1_id, ^grant_request2_id, ^grant_request3_id]}
             ] = IndexWorkerMock.calls()
    end

    @tag authentication: [role: "admin"]
    test "admin can create approved approvals using multiple ids", %{
      conn: conn,
      grant_request: %{user: user}
    } do
      IndexWorkerMock.clear()

      CacheHelpers.put_permissions_on_roles(%{
        "approve_grant_request" => ["Approval Role 1", "Approval Role 2"]
      })

      %{id: grant_request1_id} = grant_request1 = create_grant_request(user, [])

      %{id: grant_request2_id} = grant_request2 = create_grant_request(user, [])

      insert(:grant_request_approval,
        grant_request_id: grant_request2_id,
        role: "Approval Role 2"
      )

      grant_requests_ids = [
        to_string(grant_request1_id),
        to_string(grant_request2_id)
      ]

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grant_requests/_search", %{query: query, size: _}, _ ->
        assert %{bool: %{must: %{terms: %{"id" => grant_requests_ids}}}} == query

        SearchHelpers.hits_response([grant_request1, grant_request2])
      end)

      params = %{
        filters: %{id: grant_requests_ids},
        role: "Approval Role 1",
        comment: "Approval Comment",
        is_rejection: false
      }

      assert %{"data" => [first_approval | _]} =
               conn
               |> post(Routes.grant_request_bulk_approval_path(conn, :create, params))
               |> json_response(:created)

      assert %{
               "comment" => params.comment,
               "is_rejection" => params.is_rejection,
               "role" => params.role
             } == Map.take(first_approval, ["comment", "is_rejection", "role"])

      assert [
               {:reindex, _grant_requests, [^grant_request1_id, ^grant_request2_id]}
             ] = IndexWorkerMock.calls()
    end

    @tag authentication: [role: "admin"]
    @tag request_type: :grant_removal
    test "set pending removal on grant removal bulk request approve", %{
      conn: conn,
      grant_request: grant_request
    } do
      CacheHelpers.put_permissions_on_roles(%{
        "approve_grant_request" => ["foo_role"]
      })

      %{id: grant_request_id, grant_id: grant_id} = grant_request

      string_gr_id = to_string(grant_request_id)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grant_requests/_search", %{query: query, size: _}, _ ->
        assert %{bool: %{must: %{term: %{"id" => string_gr_id}}}} == query

        SearchHelpers.hits_response([grant_request])
      end)

      params = %{
        filters: %{id: [string_gr_id]},
        role: "foo_role",
        comment: "Approval Comment",
        is_rejection: false
      }

      assert %{"data" => [_first_approval]} =
               conn
               |> post(Routes.grant_request_bulk_approval_path(conn, :create, params))
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, grant_id))
               |> json_response(:ok)

      assert %{"id" => ^grant_id, "pending_removal" => true} = data
    end
  end

  defp create_grant_request(context) do
    %{claims: %{user_id: user_id, user_name: user_name}} = context

    user = %{id: user_id, user_name: user_name, full_name: "", email: ExMachina.sequence("email")}
    request_type = Map.get(context, :request_type, :grant_access)

    grant_request =
      case context do
        %{domain: domain} ->
          create_grant_request(user, [domain.id], request_type)

        _ ->
          %{id: domain_id} = CacheHelpers.insert_domain()
          create_grant_request(user, [domain_id], request_type)
      end

    [grant_request: grant_request]
  end

  defp create_grant_request(%{id: user_id} = user, domain_ids, request_type \\ :grant_access) do
    group = insert(:grant_request_group, user_id: user_id, created_by_id: user_id)
    dsv = get_dsv(domain_ids, request_type)

    data_structure_id =
      if is_nil(dsv) do
        nil
      else
        dsv.data_structure_id
      end

    insert(:grant_request,
      group: group,
      domain_ids: domain_ids,
      request_type: request_type,
      data_structure_id: data_structure_id
    )
    |> Map.put(:user, user)
    |> Map.put(:created_by, user)
    |> Map.put(:current_status, "pending")
    |> Map.put(:data_structure_version, dsv)
  end

  defp get_dsv(_domain_ids, request_type) when request_type in [:grant_removal], do: nil

  defp get_dsv(domain_ids, _request_type) do
    data_structure = insert(:data_structure, domain_ids: domain_ids)
    data_structure_version = insert(:data_structure_version, data_structure: data_structure)
    Hierarchy.update_hierarchy([data_structure_version.id])

    data_structure_version
  end
end
