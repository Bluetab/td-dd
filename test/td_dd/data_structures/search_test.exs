defmodule TdDd.DataStructures.SearchTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdDd.DataStructures.Search

  @aggregations %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  describe "get_filter_values/3" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} account filters using match_all", %{claims: claims} do
        for permission <- ["link_data_structure", "view_data_structure"] do
          ElasticsearchMock
          |> expect(:request, fn
            _, :post, "/structures/_search", %{size: 0, query: query, aggs: _}, _ ->
              assert %{bool: %{filter: %{match_all: %{}}}} = query
              SearchHelpers.aggs_response(@aggregations)
          end)

          assert {:ok, %{"foo" => %{values: ["bar", "baz"]}}} =
                   Search.get_filter_values(claims, permission, %{})
        end
      end
    end

    @tag authentication: [role: "user"]
    test "user without permissions filters by match_none", %{claims: claims} do
      for permission <- ["link_data_structure", "view_data_structure"] do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/structures/_search", %{size: 0, query: query, aggs: _}, _ ->
            assert %{bool: %{filter: %{match_none: %{}}}} = query
            SearchHelpers.aggs_response()
        end)

        assert Search.get_filter_values(claims, permission, %{}) == {:ok, %{}}
      end
    end

    @tag authentication: [
           role: "user",
           permissions: ["link_data_structure", "view_data_structure"]
         ]
    test "user with permissions filters by domain_ids", %{claims: claims} do
      for permission <- ["link_data_structure", "view_data_structure"] do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/structures/_search", %{size: 0, query: query, aggs: _}, _ ->
            assert %{
                     bool: %{
                       filter: [
                         %{term: %{"confidential" => false}},
                         %{term: %{"domain_ids" => _}}
                       ]
                     }
                   } = query

            SearchHelpers.aggs_response(@aggregations)
        end)

        assert {:ok, %{"foo" => %{values: ["bar", "baz"]}}} =
                 Search.get_filter_values(claims, permission, %{})
      end
    end
  end
end
