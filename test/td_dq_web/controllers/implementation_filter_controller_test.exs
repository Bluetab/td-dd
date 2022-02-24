defmodule TdDqWeb.ImplementationFilterControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  import Mox

  @aggs %{"rule.name.raw" => %{"buckets" => [%{"key" => "foo"}, %{"key" => "bar"}]}}

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "maps filters from request parameters", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert query == %{
                   bool: %{
                     filter: %{term: %{"rule.name.raw" => "foo"}},
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.aggs_response(@aggs)
      end)

      filters = %{"rule" => ["foo"]}

      assert %{"data" => data} =
               conn
               |> put_req_header("content-type", "application/json")
               |> post(Routes.implementation_filter_path(conn, :search, %{"filters" => filters}))
               |> json_response(:ok)

      assert data == %{"rule.name.raw" => ["foo", "bar"]}
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "user with permissions filters by domain_id and not confidential", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"domain_id" => _}},
                       %{term: %{"_confidential" => false}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.implementation_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permissions filters by domain_id and confidential", %{
      conn: conn,
      claims: claims
    } do
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain(parent_id: id1)

      CacheHelpers.put_session_permissions(claims, %{
        "view_quality_rule" => [id1],
        "manage_confidential_business_concepts" => [id2]
      })

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{terms: %{"domain_id" => [_, _]}},
                       %{
                         bool: %{
                           should: [
                             %{term: %{"domain_id" => ^id2}},
                             %{term: %{"_confidential" => false}}
                           ]
                         }
                       }
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.implementation_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions includes match_none", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert query == %{
                   bool: %{
                     filter: %{match_none: %{}},
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.implementation_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end
  end
end
