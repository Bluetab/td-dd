defmodule TdDd.GrantRequests.SearchTest do
  use TdDqWeb.ConnCase

  import Mox

  alias TdDd.GrantRequests.Search

  @aggs %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  describe "get_filter_values/2" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "searches and returns filters for #{role} account", %{claims: claims} do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/grant_requests/_search", %{aggs: _, query: query, size: 0}, _ ->
            assert %{bool: %{filter: %{match_all: %{}}}} = query
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
                     filter: %{
                       bool: %{should: [%{term: %{"data_structure_version.domain_ids" => _}}]}
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
                     filter: [
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
end
