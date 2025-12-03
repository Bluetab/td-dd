defmodule TdDdWeb.DataStructureFilterControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  @aggregations %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup :verify_on_exit!

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all filters (admin user)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, _ ->
        assert query == %{bool: %{must: %{match_all: %{}}}}
        SearchHelpers.aggs_response(@aggregations)
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_filter_path(conn, :index))
               |> json_response(:ok)

      assert %{"foo" => %{"values" => ["bar", "baz"]}} = data
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "lists all filters (non-admin user)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, _ ->
        assert query == %{bool: %{must: %{match_none: %{}}}}
        SearchHelpers.aggs_response(%{})
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_filter_path(conn, :index))
               |> json_response(:ok)

      assert data == %{}
    end
  end

  describe "search" do
    @tag authentication: [role: "admin"]
    test "returns filters with search params", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _query}, _ ->
        SearchHelpers.aggs_response(@aggregations)
      end)

      params = %{"status" => ["current"]}

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_filter_path(conn, :search), params)
               |> json_response(:ok)

      assert %{"foo" => %{"values" => ["bar", "baz"]}} = data
    end

    @tag authentication: [role: "admin"]
    test "uses create_grant_request permission when my_grant_requests is true", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _query}, _ ->
        SearchHelpers.aggs_response(@aggregations)
      end)

      params = %{"my_grant_requests" => true}

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_filter_path(conn, :search), params)
               |> json_response(:ok)

      assert %{"foo" => %{"values" => ["bar", "baz"]}} = data
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "returns filters for non-admin user", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _query}, _ ->
        SearchHelpers.aggs_response(%{})
      end)

      params = %{}

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_filter_path(conn, :search), params)
               |> json_response(:ok)

      assert data == %{}
    end
  end

  describe "get_bucket_paths" do
    @tag authentication: [role: "admin"]
    test "returns bucket paths for admin", %{conn: conn} do
      bucket_filters = %{"foo" => ["bar"]}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: _}, _ ->
        SearchHelpers.aggs_response(%{
          "id_path" => %{
            "buckets" => [
              %{
                "key" => "1",
                "filtered_children_ids" => %{"buckets" => [%{"key" => "2"}]}
              }
            ]
          }
        })
      end)

      assert %{"filtered_children" => filtered_children, "forest" => forest} =
               conn
               |> post(Routes.data_structure_filter_path(conn, :get_bucket_paths), bucket_filters)
               |> json_response(:ok)

      assert is_map(filtered_children)
      assert is_map(forest)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "returns bucket paths for non-admin user", %{conn: conn} do
      bucket_filters = %{"foo" => ["bar"]}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: _}, _ ->
        SearchHelpers.aggs_response(%{
          "id_path" => %{"buckets" => []}
        })
      end)

      assert %{"filtered_children" => filtered_children, "forest" => forest} =
               conn
               |> post(Routes.data_structure_filter_path(conn, :get_bucket_paths), bucket_filters)
               |> json_response(:ok)

      assert filtered_children == %{}
      assert forest == %{}
    end

    @tag authentication: [role: "admin"]
    test "returns bucket paths with empty filters", %{conn: conn} do
      bucket_filters = %{}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: _, aggs: _}, _ ->
        SearchHelpers.aggs_response(%{
          "id_path" => %{"buckets" => []}
        })
      end)

      assert %{"filtered_children" => filtered_children, "forest" => forest} =
               conn
               |> post(Routes.data_structure_filter_path(conn, :get_bucket_paths), bucket_filters)
               |> json_response(:ok)

      assert filtered_children == %{}
      assert forest == %{}
    end
  end
end
