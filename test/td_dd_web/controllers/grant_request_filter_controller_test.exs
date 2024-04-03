defmodule TdDdWeb.GrantRequestFilterControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  @aggregations %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup_all do
    :ok
  end

  setup :verify_on_exit!

  describe "POST /api/grant_requests_filters/search" do
    @tag authentication: [role: "admin"]
    test "includes a match_all filters for admin", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grant_requests/_search", %{query: query, size: 0, aggs: _}, _ ->
          assert query == %{bool: %{must: %{match_all: %{}}}}

          SearchHelpers.aggs_response(@aggregations)
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_filter_path(conn, :search, %{}))
               |> json_response(:ok)

      assert %{"foo" => %{"values" => ["bar", "baz"]}} = data
    end

    @tag authentication: [user_name: "non_admin_user", permissions: ["approve_grant_request"]]
    test "filters by permissions with non-admin user", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grant_requests/_search", %{query: query, size: 0, aggs: _}, _ ->
          assert %{
                   bool: %{
                     must: %{
                       bool: %{
                         should: [
                           %{term: %{"domain_ids" => _}}
                         ]
                       }
                     }
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => %{}} =
               conn
               |> post(Routes.grant_request_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end
  end

  @tag authentication: [user_name: "non_admin_user", permissions: ["approve_grant_request"]]
  test "includes filerts from request parameters", %{conn: conn} do
    ElasticsearchMock
    |> expect(:request, fn
      _, :post, "/grant_requests/_search", %{query: query, size: 0}, _ ->
        assert %{
                 bool: %{
                   must: [
                     %{term: %{"foo" => "bar"}},
                     _permission_filter
                   ]
                 }
               } = query

        SearchHelpers.aggs_response()
    end)

    params = %{"filters" => %{"foo" => ["bar"]}}

    assert %{"data" => %{}} =
             conn
             |> post(Routes.grant_request_filter_path(conn, :search, params))
             |> json_response(:ok)
  end

  @tag authentication: [user_name: "non_admin"]
  test "not include filerts if user dont have permissions", %{conn: conn} do
    ElasticsearchMock
    |> expect(:request, fn
      _, :post, "/grant_requests/_search", %{query: query, size: 0, aggs: _}, _ ->
        assert %{bool: %{must: %{match_none: %{}}}} = query
        SearchHelpers.aggs_response()
    end)

    assert %{"data" => %{}} =
             conn
             |> post(Routes.grant_request_filter_path(conn, :search, %{}))
             |> json_response(:ok)
  end
end
