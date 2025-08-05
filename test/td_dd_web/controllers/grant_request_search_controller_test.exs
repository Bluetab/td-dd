defmodule TdDdWeb.GrantRequestSearchControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.Hierarchy

  @moduletag sandbox: :shared

  @query_size 20

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    IndexWorkerMock.clear()

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
      expect(ElasticsearchMock, :request, fn _,
                                             :post,
                                             "/grant_requests/_search",
                                             %{query: query, size: @query_size},
                                             _ ->
        assert %{
                 bool: %{
                   must: %{
                     multi_match: %{
                       type: "bool_prefix",
                       fields: [
                         "user.full_name",
                         "data_structure_version.ngram_name*^3",
                         "data_structure_version.ngram_original_name*^1.5",
                         "data_structure_version.ngram_path*",
                         "data_structure_version.system.name",
                         "data_structure_version.description",
                         "grant.data_structure_version.ngram_name*^3",
                         "grant.data_structure_version.ngram_original_name*^1.5",
                         "grant.data_structure_version.ngram_path*",
                         "grant.data_structure_version.system.name",
                         "grant.data_structure_version.description"
                       ],
                       query: "foo",
                       fuzziness: "AUTO",
                       lenient: true
                     }
                   }
                 }
               } == query

        SearchHelpers.hits_response([grant_request])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search, %{"query" => "foo"}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search grant requests with wildcard query", %{
      conn: conn,
      grant_request: grant_request
    } do
      expect(ElasticsearchMock, :request, fn _,
                                             :post,
                                             "/grant_requests/_search",
                                             %{query: query, size: @query_size},
                                             _ ->
        assert %{
                 bool: %{
                   must: %{
                     simple_query_string: %{
                       fields: [
                         "user.full_name",
                         "data_structure_version.name",
                         "data_structure_version.original_name",
                         "grant.data_structure_version.name",
                         "grant.data_structure_version.original_name"
                       ],
                       query: "\"foo\"",
                       quote_field_suffix: ".exact"
                     }
                   }
                 }
               } == query

        SearchHelpers.hits_response([grant_request])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search, %{"query" => "\"foo\""}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "includes scroll_id in response",
         %{conn: conn} = context do
      grant_requests =
        Enum.map(1..5, fn _ ->
          [{_, grant_request}] = create_grant_request(context)
          grant_request
        end)

      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             _,
                             [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response(grant_requests, 7)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", %{"scroll_id" => "some_scroll_id"}, _ ->
        SearchHelpers.scroll_response([], 7)
      end)

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search), %{
                 "filters" => %{"all" => true},
                 "size" => 5,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 5

      assert %{"data" => [], "scroll_id" => _scroll_id} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search), %{
                 "scroll_id" => scroll_id
               })
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "includes inserted_at filter", %{conn: conn} do
      now = NaiveDateTime.local_now()

      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             %{
                               query: %{
                                 bool: %{
                                   must: %{
                                     range: %{"inserted_at" => %{"gte" => ^now}}
                                   }
                                 }
                               }
                             },
                             [params: %{"track_total_hits" => "true"}] ->
        SearchHelpers.hits_response([])
      end)

      post(conn, Routes.grant_request_search_path(conn, :search), %{
        "must" => %{"inserted_at" => %{"gte" => now}}
      })
    end

    @tag authentication: [role: "admin"]
    test "admin can search all grant requests with pending status with must not approved_by", %{
      conn: conn,
      grant_request: grant_request
    } do
      ElasticsearchMock
      |> expect(:request, fn _,
                             :post,
                             "/grant_requests/_search",
                             %{query: query, size: @query_size},
                             _ ->
        assert %{
                 bool: %{
                   must: %{term: %{"current_status" => "pending"}},
                   must_not: %{term: %{"approved_by" => "rol1"}}
                 }
               } ==
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
                       should: shoulds
                     }
                   }
                 }
               } = query

        assert %{term: %{"domain_ids" => domain_id}} in shoulds
        SearchHelpers.hits_response([grant_request])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_request_search_path(conn, :search))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "user without permissions filters by none",
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

    @tag authentication: [user_name: "non_admin_user"]
    test "user with permissions also filters by data_structure_id",
         %{
           conn: conn,
           claims: %{user_id: user_id} = claims,
           grant_request: grant_request
         } do
      %{data_structure_id: data_structure_id} = grant_request
      %{id: random_domain_id} = CacheHelpers.insert_domain()
      _another_domain = CacheHelpers.insert_domain()

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
                       should: shoulds
                     }
                   }
                 }
               } = query

        assert %{term: %{"domain_ids" => random_domain_id}} in shoulds
        assert %{term: %{"data_structure_id" => data_structure_id}} in shoulds

        SearchHelpers.hits_response([grant_request])
      end)

      role_name = "approver_role"
      CacheHelpers.put_permissions_on_roles(%{"approve_grant_request" => [role_name]})

      CacheHelpers.put_session_permissions(
        claims,
        %{
          "domain" => %{"approve_grant_request" => [random_domain_id]},
          "structure" => %{"approve_grant_request" => [data_structure_id]}
        }
      )

      CacheHelpers.put_grant_request_approvers([
        %{
          user_id: user_id,
          resource_ids: [data_structure_id],
          role: role_name,
          resource_type: "structure"
        },
        %{
          user_id: user_id,
          resource_ids: [random_domain_id],
          role: role_name,
          resource_type: "domain"
        }
      ])

      assert %{"data" => [_], "_permissions" => [^role_name]} =
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
