defmodule TdDdWeb.GrantRequestSearchControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.Hierarchy

  @moduletag sandbox: :shared

  @query_size 1000

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  setup :verify_on_exit!

  describe "search" do
    setup :create_grant_request

    @tag authentication: [role: "admin"]
    test "admin can search all grant requests with pending status", %{
      conn: conn,
      grant_request: grant_request
    } do
      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             %{query: query, size: @query_size},
                             _ ->
        assert %{bool: %{must: %{match_all: %{}}}} == query

        SearchHelpers.hits_response([grant_request])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search all grant requests with pending status with mut not approved_by", %{
      conn: conn,
      grant_request: grant_request
    } do
      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             %{query: query, size: @query_size},
                             _ ->
        assert %{bool: %{must: %{match_all: %{}}, must_not: %{term: %{"approved_by" => "rol1"}}}} ==
                 query

        SearchHelpers.hits_response([grant_request])
      end)

      params = %{
        "must" => %{
          "must_not_approved_by" => ["rol1"]
        }
      }

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search, params))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user", permissions: ["approve_grant_request"]]
    test "user with permissions filters by domain_id",
         %{
           conn: conn,
           grant_request: grant_request,
           domain: %{id: domain_id}
         } do
      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             %{query: query, size: @query_size},
                             _ ->
        assert %{
                 bool: %{
                   must: %{
                     bool: %{
                       should: [%{term: %{"domain_ids" => ^domain_id}}]
                     }
                   }
                 }
               } = query

        SearchHelpers.hits_response([grant_request])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "user with out permissions filters by none",
         %{
           conn: conn,
           grant_request: grant_request
         } do
      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             %{query: query, size: @query_size},
                             _ ->
        assert %{bool: %{must: %{match_none: %{}}}} = query

        SearchHelpers.hits_response([grant_request])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search))
               |> json_response(:ok)
    end
  end

  describe "reindex" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "reindex all grant requests on ElasticSearch for #{role} role", %{conn: conn} do
        IndexWorkerMock.clear()

        Enum.map(1..5, fn _ ->
          insert(:grant_request, group: insert(:grant_request_group))
        end)

        assert conn
               |> get(Routes.grant_request_search_path(conn, :reindex_all))
               |> response(:accepted)

        assert [{:reindex, :grant_requests, :all}] = IndexWorkerMock.calls()
      end
    end

    @tag authentication: [role: "non_admin"]
    test "user without admin privileges cannot reindex all grant requests", %{conn: conn} do
      IndexWorkerMock.clear()
      insert(:grant_request, group: insert(:grant_request_group))

      assert conn
             |> get(Routes.grant_request_search_path(conn, :reindex_all))
             |> response(:forbidden)

      assert [] = IndexWorkerMock.calls()
    end
  end

  defp create_grant_request(context) do
    %{claims: %{user_id: user_id, user_name: user_name}} = context
    user = %{id: user_id, user_name: user_name, full_name: "", email: ExMachina.sequence("email")}

    grant_request =
      case context do
        %{domain: domain} ->
          create_grant_request(user, [domain.id])

        _ ->
          create_grant_request(user, [])
      end

    [grant_request: grant_request]
  end

  defp create_grant_request(user, domain_ids) do
    data_structure = insert(:data_structure, domain_ids: domain_ids)
    data_structure_version = insert(:data_structure_version, data_structure: data_structure)
    Hierarchy.update_hierarchy([data_structure_version.id])
    group = insert(:grant_request_group, user_id: user.id, created_by_id: user.id)

    grant_request =
      insert(:grant_request,
        group: group,
        data_structure: data_structure,
        domain_ids: domain_ids
      )

    grant_request
    |> Map.put(:data_structure_version, data_structure_version)
    |> Map.put(:user, user)
    |> Map.put(:created_by, user)
    |> Map.put(:current_status, "pending")
  end
end
