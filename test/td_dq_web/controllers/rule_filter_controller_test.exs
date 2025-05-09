defmodule TdDqWeb.RuleFilterControllerTest do
  use TdDqWeb.ConnCase

  import Mox

  @aggs %{"domain_id" => %{"buckets" => [%{"key" => 1}, %{"key" => 2}]}}

  setup :verify_on_exit!

  describe "index" do
    @tag authentication: [role: "admin"]
    test "maps filters from request parameters", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query, size: 0}, _ ->
          assert query == %{bool: %{must: %{term: %{"domain_id" => "1"}}}}
          SearchHelpers.aggs_response(@aggs)
      end)

      filters = %{"domain_id" => [1]}

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_filter_path(conn, :search, %{"filters" => filters}))
               |> json_response(:ok)

      assert %{"domain_id" => %{"values" => [1, 2]}} = data
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "user with permissions filters by domain_id and not confidential", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     must: [
                       %{term: %{"_confidential" => false}},
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.rule_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permissions filters by domain_ids and confidential", %{
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
        _, :post, "/rules/_search", %{query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     must: [
                       %{
                         bool: %{
                           should: [
                             %{term: %{"domain_ids" => ^id2}},
                             %{term: %{"_confidential" => false}}
                           ]
                         }
                       },
                       %{terms: %{"domain_ids" => [_, _]}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.rule_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions includes match_none", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query, size: 0}, _ ->
          assert query == %{bool: %{must: %{match_none: %{}}}}
          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.rule_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end
  end
end
