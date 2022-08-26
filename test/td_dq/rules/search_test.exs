defmodule TdDq.Rules.SearchTest do
  use TdDqWeb.ConnCase

  import Mox

  alias TdDq.Rules.Search

  @aggs %{"active.raw" => %{"buckets" => [%{"key" => "true"}, %{"key" => "false"}]}}

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  describe "get_filter_values/3" do
    for role <- ["admin", "service", "user"] do
      @tag authentication: [role: role, permissions: ["view_quality_rule"]]
      test "searches and returns filters for #{role} account", %{claims: claims} do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/rules/_search", %{aggs: _, query: _, size: 0}, [] ->
            SearchHelpers.aggs_response(@aggs)
        end)

        assert {:ok, %{"active.raw" => ["true", "false"]}} =
                 Search.get_filter_values(claims, _params = %{})
      end
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "filters by domain_ids and not confidential", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{aggs: _, query: query, size: 0}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"_confidential" => false}},
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok, _} = Search.get_filter_values(claims, _params = %{})
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule", "manage_confidential_business_concepts"]
         ]
    test "filters by domain_ids or confidential", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{aggs: _, query: query, size: 0}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{
                         bool: %{
                           should: [
                             %{term: %{"domain_ids" => _}},
                             %{term: %{"_confidential" => false}}
                           ]
                         }
                       },
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok, _} = Search.get_filter_values(claims, _params = %{})
    end

    @tag authentication: [role: "user"]
    test "filters by executable permission iff executable param is present", %{
      claims: claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: executable_domain_id} = CacheHelpers.insert_domain(parent_id: domain_id)

      CacheHelpers.put_session_permissions(claims, %{
        "view_quality_rule" => [domain_id],
        "execute_quality_rule_implementations" => [executable_domain_id]
      })

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"_confidential" => false}},
                       %{terms: %{"domain_ids" => [_, _]}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response(@aggs)
      end)
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"domain_ids" => ^executable_domain_id}},
                       %{term: %{"executable" => true}},
                       %{term: %{"_confidential" => false}},
                       %{terms: %{"domain_ids" => [_, _]}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok, _} = Search.get_filter_values(claims, %{}, :implementations)

      assert {:ok, _} =
               Search.get_filter_values(
                 claims,
                 %{"filters" => %{"executable" => [true]}},
                 :implementations
               )
    end

    @tag authentication: [role: "admin"]
    test "aggregations for rules", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{aggs: aggs, query: _, size: 0}, [] ->
          assert %{"active.raw" => _, "taxonomy" => _} = aggs
          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok, %{"active.raw" => ["true", "false"]}} =
               Search.get_filter_values(claims, _params = %{})
    end

    @tag authentication: [role: "admin"]
    test "aggregations for implementations", %{claims: claims} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{aggs: aggs, query: _, size: 0}, [] ->
          assert %{"source_external_id" => _, "rule" => _} = aggs
          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok, %{"active.raw" => ["true", "false"]}} =
               Search.get_filter_values(claims, _params = %{}, :implementations)
    end

    @tag authentication: [role: "service"]
    test "includes default status filter for service role", %{claims: claims} do
      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{"view_quality_rule" => [domain_id]})

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert query == %{bool: %{filter: %{term: %{"status" => "published"}}}}
          SearchHelpers.aggs_response(@aggs)
      end)
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query, size: 0}, [] ->
          assert query == %{bool: %{filter: %{term: %{"status" => "foo"}}}}
          SearchHelpers.aggs_response(@aggs)
      end)

      assert {:ok, _} = Search.get_filter_values(claims, %{}, :implementations)

      assert {:ok, _} =
               Search.get_filter_values(
                 claims,
                 %{"filters" => %{"status" => ["foo"]}},
                 :implementations
               )
    end
  end

  describe "search_rules/4" do
    setup :create_rule

    for role <- ["admin", "service", "user"] do
      @tag authentication: [role: role, permissions: ["view_quality_rule"]]
      test "searches and returns hits for #{role} account", %{claims: claims, rule: rule} do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/rules/_search", %{from: 30, size: 10, query: _} = search, [] ->
            refute Map.has_key?(search, :aggs)
            SearchHelpers.hits_response([rule], 11)
        end)

        assert %{results: [_], total: 11} = Search.search_rules(_params = %{}, claims, 3, 10)
      end
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "filters by domain_ids and not confidential", %{claims: claims, rule: rule} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{from: 0, size: 50, query: query}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"_confidential" => false}},
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.hits_response([rule])
      end)

      assert %{results: [_]} = Search.search_rules(_params = %{}, claims)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule", "manage_confidential_business_concepts"]
         ]
    test "filters by domain_ids or confidential", %{claims: claims, rule: rule} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{
                         bool: %{
                           should: [
                             %{term: %{"domain_ids" => _}},
                             %{term: %{"_confidential" => false}}
                           ]
                         }
                       },
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.hits_response([rule])
      end)

      assert %{results: [_]} = Search.search_rules(_params = %{}, claims)
    end

    @tag authentication: [role: "service"]
    test "includes scroll as query param", %{claims: claims, rule: rule} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: _}, [params: %{"scroll" => "1m"}] ->
          SearchHelpers.hits_response([rule])
      end)

      params = %{"scroll" => "1m"}
      assert %{results: [_]} = Search.search_rules(params, claims)
    end
  end

  describe "search_implementations/4" do
    setup :create_implementation

    for role <- ["admin", "service", "user"] do
      @tag authentication: [role: role, permissions: ["view_quality_rule"]]
      test "searches and returns hits for #{role} account", %{
        claims: claims,
        implementation: implementation
      } do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/implementations/_search", %{from: 30, size: 10, query: _} = search, [] ->
            refute Map.has_key?(search, :aggs)
            SearchHelpers.hits_response([implementation], 11)
        end)

        assert %{results: [_], total: 11} =
                 Search.search_implementations(_params = %{}, claims, 3, 10)
      end
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "filters by domain_ids and not confidential", %{
      claims: claims,
      implementation: implementation
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{from: 0, size: 50, query: query}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"_confidential" => false}},
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.hits_response([implementation])
      end)

      assert %{results: [_]} = Search.search_implementations(_params = %{}, claims)
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule", "manage_confidential_business_concepts"]
         ]
    test "filters by domain_ids or confidential", %{
      claims: claims,
      implementation: implementation
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{
                         bool: %{
                           should: [
                             %{term: %{"domain_ids" => _}},
                             %{term: %{"_confidential" => false}}
                           ]
                         }
                       },
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.hits_response([implementation])
      end)

      assert %{results: [_]} = Search.search_implementations(_params = %{}, claims)
    end

    @tag authentication: [role: "user"]
    test "filters by executable permission iff executable param is present", %{
      claims: claims,
      implementation: implementation
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: executable_domain_id} = CacheHelpers.insert_domain(parent_id: domain_id)

      CacheHelpers.put_session_permissions(claims, %{
        "view_quality_rule" => [domain_id],
        "execute_quality_rule_implementations" => [executable_domain_id]
      })

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: query}, [] ->
          assert %{
                   bool: %{
                     filter: [
                       %{term: %{"domain_ids" => ^executable_domain_id}},
                       %{term: %{"executable" => true}},
                       %{term: %{"_confidential" => false}},
                       %{terms: %{"domain_ids" => [_, _]}}
                     ]
                   }
                 } = query

          SearchHelpers.hits_response([implementation])
      end)

      params = %{"filters" => %{"executable" => [true]}}
      assert %{results: [_]} = Search.search_implementations(params, claims)
    end

    @tag authentication: [role: "service"]
    test "includes scroll as query param", %{claims: claims, implementation: implementation} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{query: _}, [params: %{"scroll" => "1m"}] ->
          SearchHelpers.hits_response([implementation])
      end)

      params = %{"scroll" => "1m"}
      assert %{results: [_]} = Search.search_implementations(params, claims)
    end
  end

  defp create_rule(_), do: [rule: insert(:rule)]
  defp create_implementation(_), do: [implementation: insert(:implementation)]
end
