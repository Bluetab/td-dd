defmodule TdDqWeb.ImplementationSearchControllerTest do
  use TdDqWeb.ConnCase

  import Mox

  @business_concept_id "42"

  setup :verify_on_exit!

  setup context do
    %{id: domain_id} =
      domain =
      case context do
        %{domain: domain} -> domain
        _ -> CacheHelpers.insert_domain()
      end

    %{id: concept_id} = CacheHelpers.insert_concept(%{domain_id: domain_id})
    rule = insert(:rule, business_concept_id: concept_id, domain_id: domain_id)
    implementation = insert(:implementation, rule: rule, domain_id: domain_id)
    [domain: domain, implementation: implementation, rule: rule]
  end

  describe "POST /api/rule_implementations/search" do
    @tag authentication: [role: "admin"]
    test "admin can search implementations", %{conn: conn, implementation: implementation} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/implementations/_search", _, _ ->
        SearchHelpers.hits_response([implementation])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "admin can search implementations with must params", %{
      conn: conn,
      implementation: implementation
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/implementations/_search", %{query: query}, _ ->
        assert %{bool: %{must: %{match_all: %{}}}} == query

        SearchHelpers.hits_response([implementation])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "must" => %{}
               })
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search implementations", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search implementations with must", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{"must" => %{}})
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_rule",
             "manage_quality_rule_implementations",
             "execute_quality_rule_implementations"
           ]
         ]
    test "user with permissions can search implementations", %{
      conn: conn,
      implementation: implementation
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/implementations/_search", %{query: query}, _ ->
        assert %{
                 bool: %{
                   must: [
                     %{term: %{"_confidential" => false}},
                     %{term: %{"domain_ids" => _}}
                   ],
                   must_not: %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 }
               } = query

        SearchHelpers.hits_response([implementation])
      end)

      assert %{"data" => [_], "_actions" => actions} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)

      assert %{"download" => %{"method" => "POST"}, "create" => %{"method" => "POST"}} == actions
    end

    @tag authentication: [
           role: "user",
           permissions: [
             "view_quality_rule",
             "manage_quality_rule_implementations",
             "execute_quality_rule_implementations"
           ]
         ]
    test "user with permissions can search implementations with must", %{
      conn: conn,
      implementation: implementation
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/implementations/_search", %{query: query}, _ ->
        assert %{
                 bool: %{
                   must: [
                     %{term: %{"_confidential" => false}},
                     %{term: %{"domain_ids" => _}}
                   ],
                   must_not: %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 }
               } = query

        SearchHelpers.hits_response([implementation])
      end)

      assert %{"data" => [_], "_actions" => actions} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{"must" => %{}})
               |> json_response(:ok)

      assert %{"download" => %{"method" => "POST"}, "create" => %{"method" => "POST"}} == actions
    end

    @tag authentication: [user_name: "not_an_admin", permissions: [:view_quality_rule]]
    test "only includes download action if user has view_quality_rule permission", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([]) end)

      assert %{"_actions" => actions} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)

      assert actions == %{"download" => %{"method" => "POST"}}
    end

    @tag authentication: [user_name: "not_an_admin", permissions: [:view_quality_rule]]
    test "only includes download action if user has view_quality_rule permission with must param",
         %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([]) end)

      assert %{"_actions" => actions} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{"must" => %{}})
               |> json_response(:ok)

      assert actions == %{"download" => %{"method" => "POST"}}
    end

    @tag authentication: [
           user_name: "not_an_admin",
           permissions: [:manage_rule_results, :view_quality_rule]
         ]
    test "includes actions if user has manage_rule_results permission", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([]) end)

      params = %{"filters" => %{"status" => ["published"]}}

      assert %{"_actions" => actions} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), params)
               |> json_response(:ok)

      assert %{"uploadResults" => %{"method" => "POST"}} = actions
    end

    @tag authentication: [
           user_name: "not_an_admin",
           permissions: [:manage_rule_results, :view_quality_rule]
         ]
    test "includes actions if user has manage_rule_results permission with must", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([]) end)

      params = %{"must" => %{"status" => ["published"]}}

      assert %{"_actions" => actions} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), params)
               |> json_response(:ok)

      assert %{"uploadResults" => %{"method" => "POST"}} = actions
    end
  end

  describe "search with scroll" do
    @tag authentication: [role: "admin"]
    test "return scroll_id and pages results", %{conn: conn, domain: %{id: domain_id}} do
      rule = insert(:rule, business_concept_id: @business_concept_id, domain_id: domain_id)
      impls = Enum.map(1..7, fn _ -> insert(:implementation, rule: rule) end)

      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/implementations/_search",
        %{from: 0, size: 5},
        [params: %{"scroll" => "1m"}] ->
          SearchHelpers.scroll_response(Enum.take(impls, 5))
      end)
      |> expect(:request, fn
        _, :post, "/_search/scroll", body, [] ->
          assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
          SearchHelpers.scroll_response(Enum.drop(impls, 5))
      end)

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "size" => 5,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 5

      assert %{"data" => data, "scroll_id" => _} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 2
    end

    @tag authentication: [role: "admin"]
    test "return scroll_id and pages results con must", %{conn: conn, domain: %{id: domain_id}} do
      rule = insert(:rule, business_concept_id: @business_concept_id, domain_id: domain_id)
      impls = Enum.map(1..7, fn _ -> insert(:implementation, rule: rule) end)

      ElasticsearchMock
      |> expect(:request, fn
        _,
        :post,
        "/implementations/_search",
        %{from: 0, size: 5},
        [params: %{"scroll" => "1m"}] ->
          SearchHelpers.scroll_response(Enum.take(impls, 5))
      end)
      |> expect(:request, fn
        _, :post, "/_search/scroll", body, [] ->
          assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
          SearchHelpers.scroll_response(Enum.drop(impls, 5))
      end)

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "size" => 5,
                 "scroll" => "1m",
                 "must" => %{}
               })
               |> json_response(:ok)

      assert length(data) == 5

      assert %{"data" => data, "scroll_id" => _} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m",
                 "must" => %{}
               })
               |> json_response(:ok)

      assert length(data) == 2
    end
  end
end
