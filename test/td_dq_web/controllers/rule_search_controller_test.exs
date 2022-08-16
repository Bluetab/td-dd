defmodule TdDqWeb.RuleSearchControllerTest do
  use TdDqWeb.ConnCase

  import Mox

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup do
    %{id: domain_id} = domain = CacheHelpers.insert_domain()
    %{id: concept_id} = CacheHelpers.insert_concept(name: "Concept", domain_id: domain_id)
    rule = insert(:rule, business_concept_id: concept_id, domain_id: domain_id)
    implementation = insert(:implementation, rule: rule)
    [domain: domain, implementation: implementation, rule: rule]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "admin can search rules", %{conn: conn, rule: rule} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query, size: 20}, [] ->
          assert query == %{bool: %{filter: %{match_all: %{}}}}
          SearchHelpers.hits_response([rule])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.rule_search_path(conn, :create))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with no permissions cannot search rules", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query, size: 20}, [] ->
          assert query == %{bool: %{filter: %{match_none: %{}}}}
          SearchHelpers.hits_response([])
      end)

      assert %{"data" => []} =
               conn
               |> post(Routes.rule_search_path(conn, :create))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user", permissions: [:view_quality_rule]]
    test "user with permissions can search rules", %{conn: conn, rule: rule} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", %{query: query, size: 20}, [] ->
          assert %{
                   bool: %{
                     filter: [_not_confidential, %{term: %{"domain_ids" => _}}],
                     must_not: _must_not
                   }
                 } = query

          SearchHelpers.hits_response([rule])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.rule_search_path(conn, :create))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user", permissions: [:manage_quality_rule]]
    test "user with permissions to create rules has manage_quality_rules equals true", %{
      conn: conn
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", _, [] -> SearchHelpers.hits_response([])
      end)

      assert %{"user_permissions" => %{"manage_quality_rules" => true}} =
               conn
               |> post(Routes.rule_search_path(conn, :create))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions to create rules has manage_quality_rules equals false", %{
      conn: conn
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/rules/_search", _, [] -> SearchHelpers.hits_response([])
      end)

      assert %{"user_permissions" => %{"manage_quality_rules" => false}} =
               conn
               |> post(Routes.rule_search_path(conn, :create))
               |> json_response(:ok)
    end
  end
end
