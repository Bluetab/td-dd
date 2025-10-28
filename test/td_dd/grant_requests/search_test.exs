defmodule TdDd.GrantRequests.SearchTest do
  use TdDqWeb.ConnCase

  import Mox

  alias TdDd.GrantRequests.Search

  @aggs %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup :verify_on_exit!

  describe "get_filter_values/2" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "searches and returns filters for #{role} account", %{claims: claims} do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/grant_requests/_search", %{aggs: _, query: query, size: 0}, _ ->
            assert %{bool: %{must: %{match_all: %{}}}} = query
            SearchHelpers.aggs_response(@aggs)
        end)

        assert {:ok, %{"foo" => %{values: ["bar", "baz"]}}} =
                 Search.get_filter_values(claims, %{})
      end
    end

    @tag authentication: [role: "user", permissions: ["approve_grant_request"]]
    test "searches and returns filters for non admin user account", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grant_requests/_search", %{aggs: _, query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     must: %{
                       bool: %{should: [%{term: %{"domain_ids" => _}}]}
                     }
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert {:ok, %{}} = Search.get_filter_values(claims, %{})
    end

    @tag authentication: [role: "user", permissions: ["approve_grant_request"]]
    test "include filters from request parameters", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grant_requests/_search", %{aggs: _, query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     must: [
                       %{term: %{"foo" => "bar"}},
                       _
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      params = %{"filters" => %{"foo" => ["bar"]}}
      assert {:ok, %{}} = Search.get_filter_values(claims, params)
    end
  end

  describe "status_reason filtering support" do
    @tag authentication: [role: "admin"]
    test "supports status_reason in aggregations", %{claims: claims} do
      expected_aggs = %{
        "status_reason" => %{
          "buckets" => [
            %{"key" => "connection timeout", "doc_count" => 5},
            %{"key" => "authentication failed", "doc_count" => 3}
          ]
        }
      }

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grant_requests/_search", %{aggs: aggs, query: _, size: 0}, _ ->
          # Verify status_reason aggregation is included
          assert Map.has_key?(aggs, "status_reason")
          assert %{terms: %{field: "status_reason.keyword"}} = aggs["status_reason"]

          SearchHelpers.aggs_response(expected_aggs)
      end)

      assert {:ok,
              %{"status_reason" => %{values: ["connection timeout", "authentication failed"]}}} =
               Search.get_filter_values(claims, %{})
    end

    @tag authentication: [role: "admin"]
    test "supports filtering by status_reason in search params", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grant_requests/_search", %{aggs: _, query: query, size: 0}, _ ->
          # Verify status_reason filter is applied
          assert %{
                   bool: %{
                     must: %{
                       term: %{"status_reason.keyword" => "connection timeout"}
                     }
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      params = %{"filters" => %{"status_reason" => ["connection timeout"]}}
      assert {:ok, %{}} = Search.get_filter_values(claims, params)
    end
  end
end
