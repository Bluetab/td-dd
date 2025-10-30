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
    test "includes similarity in response", %{claims: claims} do
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

      assert %{total: 1, results: [result]} =
               Search.vector(claims, :view_data_structure, params, similarity: :cosine)

      assert result.similarity == 1.0
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

  describe "get_bucket_paths/3" do
    @tag authentication: [role: "admin"]
    test "returns bucket paths for admin", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: _}, _ ->
        SearchHelpers.aggs_response(%{
          "id_path" => %{
            "buckets" => [
              %{
                "key" => "1-2-3",
                "filtered_children_ids" => %{"buckets" => [%{"key" => "3"}]}
              },
              %{
                "key" => "1",
                "filtered_children_ids" => %{"buckets" => [%{"key" => "2"}]}
              }
            ]
          }
        })
      end)

      assert %{forest: forest, filtered_children: filtered_children} =
               Search.get_bucket_paths(claims, :view_data_structure, %{})

      assert is_map(forest)
      assert is_map(filtered_children)
    end

    @tag authentication: [role: "admin"]
    test "handles empty bucket paths", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: _}, _ ->
        SearchHelpers.aggs_response(%{"id_path" => %{"buckets" => []}})
      end)

      assert %{forest: forest, filtered_children: filtered_children} =
               Search.get_bucket_paths(claims, :view_data_structure, %{})

      assert forest == %{}
      assert filtered_children == %{}
    end

    @tag authentication: [role: "admin"]
    test "processes paths correctly", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: _}, _ ->
        SearchHelpers.aggs_response(%{
          "id_path" => %{
            "buckets" => [
              %{
                "key" => "",
                "filtered_children_ids" => %{"buckets" => [%{"key" => "1"}]}
              }
            ]
          }
        })
      end)

      assert %{forest: _forest, filtered_children: filtered_children} =
               Search.get_bucket_paths(claims, :view_data_structure, %{})

      assert filtered_children[0] == [1]
    end
  end

  describe "get_aggregations/2" do
    @tag authentication: [role: "admin"]
    test "returns aggregations for admin", %{claims: claims} do
      aggs = %{"test_agg" => %{"terms" => %{"field" => "type"}}}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: ^aggs}, _ ->
        SearchHelpers.aggs_response(%{"test_agg" => %{"buckets" => [%{"key" => "Table"}]}})
      end)

      assert {:ok, response} = Search.get_aggregations(claims, aggs)
      assert is_map(response)
    end
  end

  describe "scroll_data_structures/2" do
    @tag authentication: [role: "admin"]
    test "scrolls with scroll_id", %{claims: _claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/_search/scroll", %{"scroll_id" => "test_scroll"}, _ ->
        SearchHelpers.scroll_response([])
      end)

      params = %{"scroll_id" => "test_scroll", "scroll" => "1m"}

      assert %{results: [], scroll_id: _, total: 0} =
               Search.scroll_data_structures(params)
    end
  end

  describe "scroll_data_structures/3" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "scrolls data structures with default sort", %{claims: claims} do
      ElasticsearchMock
      |> stub(:request, fn
        _, :post, "/structures/_search", %{query: _, size: _, sort: sort}, _ ->
          assert sort == ["_score", "name.raw", "id"]
          SearchHelpers.scroll_response([insert(:data_structure_version)])

        _, :post, "/_search/scroll", _, _ ->
          SearchHelpers.scroll_response([])
      end)

      assert %{results: _, scroll_id: _, total: _} =
               Search.scroll_data_structures(%{}, claims, :view_data_structure)
    end

    @tag authentication: [role: "admin"]
    test "respects max_bulk_results limit", %{claims: claims} do
      ElasticsearchMock
      |> stub(:request, fn
        _, :post, "/structures/_search", %{query: _, size: _, sort: _}, _ ->
          SearchHelpers.scroll_response([insert(:data_structure_version)])

        _, :post, "/_search/scroll", _, _ ->
          SearchHelpers.scroll_response([])
      end)

      assert %{results: _, scroll_id: _, total: _} =
               Search.scroll_data_structures(%{}, claims, :view_data_structure)
    end

    @tag authentication: [role: "admin"]
    test "uses custom sort when provided", %{claims: claims} do
      ElasticsearchMock
      |> stub(:request, fn
        _, :post, "/structures/_search", %{query: _, size: _, sort: sort}, _ ->
          assert sort == ["custom_field"]
          SearchHelpers.scroll_response([insert(:data_structure_version)])

        _, :post, "/_search/scroll", _, _ ->
          SearchHelpers.scroll_response([])
      end)

      params = %{"sort" => ["custom_field"]}

      assert %{results: _, scroll_id: _, total: _} =
               Search.scroll_data_structures(params, claims, :view_data_structure)
    end
  end

  describe "bucket_structures/3" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "searches structures with filters", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{query: _, from: 0, size: 1000} = request
        SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      params = %{"filters" => %{"type" => ["Table"]}}

      assert %{results: [_], total: 1} =
               Search.bucket_structures(claims, :view_data_structure, params)
    end

    @tag authentication: [role: "admin"]
    test "handles query parameter", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{query: %{bool: %{must: must}}} = request
        assert Enum.any?(must, &match?(%{multi_match: _}, &1))
        SearchHelpers.hits_response([])
      end)

      params = %{"filters" => %{"type" => ["Table"]}, "query" => "test search"}

      assert %{results: [], total: 0} =
               Search.bucket_structures(claims, :view_data_structure, params)
    end

    @tag authentication: [role: "admin"]
    test "ignores empty query strings", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{query: %{bool: %{must: must}}} = request
        refute Enum.any?(must, &match?(%{multi_match: _}, &1))
        SearchHelpers.hits_response([])
      end)

      params = %{"filters" => %{}, "query" => "   "}

      assert %{results: [], total: 0} =
               Search.bucket_structures(claims, :view_data_structure, params)
    end
  end

  describe "search_data_structures/5" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "searches with default pagination", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{from: 0, size: 50, sort: ["_score", "name.raw"]} = request
        SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      assert %{results: [_], total: 1} =
               Search.search_data_structures(%{}, claims, :view_data_structure)
    end

    @tag authentication: [role: "admin"]
    test "searches with custom pagination", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{from: 20, size: 10} = request
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} =
               Search.search_data_structures(%{}, claims, :view_data_structure, 2, 10)
    end

    @tag authentication: [role: "admin"]
    test "searches with custom sort", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{sort: ["updated_at"]} = request
        SearchHelpers.hits_response([])
      end)

      params = %{"sort" => ["updated_at"]}

      assert %{results: [], total: 0} =
               Search.search_data_structures(params, claims, :view_data_structure)
    end

    @tag authentication: [role: "admin"]
    test "searches with filters", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{query: %{bool: %{must: must}}} = request
        assert is_map(must) or is_list(must)
        SearchHelpers.hits_response([])
      end)

      params = %{"filters" => %{"type" => ["Table"]}}

      assert %{results: [], total: 0} =
               Search.search_data_structures(params, claims, :view_data_structure)
    end

    @tag authentication: [user_name: "non_admin"]
    test "searches without permissions returns empty", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", request, _ ->
        assert %{query: %{bool: %{must: %{match_none: %{}}}}} = request
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} =
               Search.search_data_structures(%{}, claims, :view_data_structure)
    end
  end
end
