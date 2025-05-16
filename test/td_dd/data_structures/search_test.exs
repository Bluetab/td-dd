defmodule TdDd.DataStructures.SearchTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdDd.DataStructures.Search

  @moduletag sandbox: :shared

  @aggregations %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup :verify_on_exit!

  describe "get_filter_values/3" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} account filters using match_all", %{claims: claims} do
        for permission <- ["link_data_structure", "view_data_structure"] do
          ElasticsearchMock
          |> expect(:request, fn
            _, :post, "/structures/_search", %{size: 0, query: query, aggs: _}, _ ->
              assert %{bool: %{must: %{match_all: %{}}}} = query
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
            assert %{bool: %{must: %{match_none: %{}}}} = query
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
                       must: [
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

  describe "vector/3" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "puts vector search in elastic", %{claims: claims} do
      expect(ElasticsearchMock, :request, fn _, :post, "/structures/_search", request, _ ->
        assert request == %{
                 sort: ["_score"],
                 _source: %{excludes: ["embeddings"]},
                 knn: %{
                   "field" => "embeddings.vector_foo",
                   "filter" => %{bool: %{"filter" => %{match_all: %{}}}},
                   "k" => 10,
                   "num_candidates" => 200,
                   "query_vector" => [54.0, 10.2, -2.0],
                   "similarity" => 0.5
                 }
               }

        SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      params = %{
        "field" => "embeddings.vector_foo",
        "k" => 10,
        "similarity" => 0.5,
        "num_candidates" => 200,
        "query_vector" => [54.0, 10.2, -2.0]
      }

      assert %{total: 1, results: [_result]} =
               Search.vector(claims, :view_data_structure, params)
    end

    @tag authentication: [role: "admin"]
    test "exludes structure ids from search", %{claims: claims} do
      expect(ElasticsearchMock, :request, fn _, :post, "/structures/_search", request, _ ->
        assert request == %{
                 sort: ["_score"],
                 _source: %{excludes: ["embeddings"]},
                 knn: %{
                   "field" => "embeddings.vector_foo",
                   "filter" => %{
                     bool: %{
                       "filter" => %{match_all: %{}},
                       "must_not" => [%{term: %{"data_structure_id" => "1"}}]
                     }
                   },
                   "k" => 10,
                   "num_candidates" => 200,
                   "query_vector" => [54.0, 10.2, -2.0],
                   "similarity" => 0.5
                 }
               }

        SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      params = %{
        "field" => "embeddings.vector_foo",
        "k" => 10,
        "similarity" => 0.5,
        "num_candidates" => 200,
        "query_vector" => [54.0, 10.2, -2.0],
        "structure_ids" => ["1"]
      }

      assert %{total: 1, results: [_result]} =
               Search.vector(claims, :view_data_structure, params)
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "puts domain filters in vector search", %{claims: claims, domain: domain} do
      expect(ElasticsearchMock, :request, fn _, :post, "/structures/_search", request, _ ->
        assert request == %{
                 sort: ["_score"],
                 _source: %{excludes: ["embeddings"]},
                 knn: %{
                   "field" => "embeddings.vector_foo",
                   "filter" => %{
                     bool: %{
                       "filter" => [
                         %{term: %{"domain_ids" => domain.id}},
                         %{term: %{"confidential" => false}}
                       ]
                     }
                   },
                   "k" => 10,
                   "num_candidates" => 200,
                   "query_vector" => [54.0, 10.2, -2.0],
                   "similarity" => 0.5
                 }
               }

        SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      params = %{
        "field" => "embeddings.vector_foo",
        "k" => 10,
        "similarity" => 0.5,
        "num_candidates" => 200,
        "query_vector" => [54.0, 10.2, -2.0]
      }

      assert %{total: 1, results: [_result]} =
               Search.vector(claims, :view_data_structure, params)
    end
  end
end
