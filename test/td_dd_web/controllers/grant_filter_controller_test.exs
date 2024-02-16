defmodule TdDdWeb.GrantFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox

  @aggregations %{
    "data_structure_version.name.raw" => %{
      "buckets" => [%{"key" => "foo"}, %{"key" => "baz"}]
    }
  }

  setup_all do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  describe "POST /api/grant_filters/search" do
    @tag authentication: [role: "admin"]
    test "includes a match_all filter and must_not on deleted_at (admin user)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grants/_search", %{query: query, size: 0}, _ ->
          assert query == %{
                   bool: %{
                     filter: %{match_all: %{}},
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.aggs_response(@aggregations)
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_filter_path(conn, :search, %{}))
               |> json_response(:ok)

      assert %{"data_structure_version.name.raw" => %{"values" => ["foo", "baz"]}} = data
    end

    @tag authentication: [user_name: "non_admin_user", permissions: ["view_grants"]]
    test "filters by permissions, user_id and deleted_at (non-admin user)", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grants/_search", %{query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     filter: %{
                       bool: %{
                         should: [
                           %{term: %{"data_structure_version.domain_ids" => _}},
                           %{term: %{"user_id" => ^user_id}}
                         ]
                       }
                     },
                     must_not: _deleted_at
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      assert %{"data" => _} =
               conn
               |> post(Routes.grant_filter_path(conn, :search, %{}))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "includes filters from request parameters", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grants/_search", %{query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     filter: [%{term: %{"foo" => "bar"}}, _permission_filter]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      params = %{"filters" => %{"foo" => ["bar"]}}

      assert %{"data" => _} =
               conn
               |> post(Routes.grant_filter_path(conn, :search, params))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "includes system external_id filter from request parameters", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grants/_search", %{query: query, size: 0}, _ ->
          assert %{
                   bool: %{
                     filter: [
                       %{
                         terms: %{
                           "data_structure_version.system.external_id.raw" => ["bar", "foo"]
                         }
                       },
                       _permission_filter
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response()
      end)

      params = %{"filters" => %{"system_external_id" => ["foo", "bar"]}}

      assert %{"data" => _} =
               conn
               |> post(Routes.grant_filter_path(conn, :search, params))
               |> json_response(:ok)
    end
  end

  describe "POST /api/grant_filters/search/mine" do
    for role <- ["admin", "service", "user"] do
      @tag authentication: [role: role]
      test "filters by user_id and deleted_at (#{role} account)", %{
        conn: conn,
        claims: %{user_id: user_id}
      } do
        ElasticsearchMock
        |> expect(:request, fn
          _, :post, "/grants/_search", %{query: query, size: 0}, _ ->
            assert %{
                     bool: %{
                       filter: %{term: %{"user_id" => ^user_id}},
                       must_not: _deleted_at
                     }
                   } = query

            SearchHelpers.aggs_response(@aggregations)
        end)

        assert %{"data" => data} =
                 conn
                 |> post(Routes.grant_filter_path(conn, :search_mine, %{}))
                 |> json_response(:ok)

        assert %{"data_structure_version.name.raw" => %{"values" => ["foo", "baz"]}} = data
      end
    end
  end
end
