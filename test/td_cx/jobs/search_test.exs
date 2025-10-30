defmodule TdCx.Jobs.SearchTest do
  use TdDd.DataCase

  import Mox

  alias TdCx.Jobs.Search

  setup :verify_on_exit!

  describe "get_filter_values/2" do
    test "returns filters for admin role" do
      claims = build(:claims, role: "admin")

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{aggs: _, size: 0}, _ ->
        SearchHelpers.aggs_response(%{
          "status" => %{"buckets" => [%{"key" => "PENDING"}]}
        })
      end)

      assert {:ok, filters} = Search.get_filter_values(claims, %{})
      assert is_map(filters)
    end

    test "returns filters for service role" do
      claims = build(:claims, role: "service")

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{aggs: _, size: 0}, _ ->
        SearchHelpers.aggs_response(%{
          "type" => %{"buckets" => [%{"key" => "profile"}]}
        })
      end)

      assert {:ok, filters} = Search.get_filter_values(claims, %{})
      assert is_map(filters)
    end

    test "returns empty filters for regular users" do
      claims = build(:claims, role: "user")

      assert {:ok, %{}} = Search.get_filter_values(claims, %{})
    end

    test "accepts filter parameters for admin" do
      claims = build(:claims, role: "admin")
      params = %{"filters" => %{"status" => ["PENDING"]}}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{aggs: _, size: 0, query: _}, _ ->
        SearchHelpers.aggs_response(%{})
      end)

      assert {:ok, _filters} = Search.get_filter_values(claims, params)
    end
  end

  describe "search_jobs/4" do
    test "searches jobs for admin with default pagination" do
      claims = build(:claims, role: "admin")

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", request, _ ->
        assert %{from: 0, size: 50, sort: ["_score", "external_id.raw"]} = request
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(%{}, claims)
    end

    test "searches jobs for service account" do
      claims = build(:claims, role: "service")

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", request, _ ->
        assert %{from: 0, size: 50} = request
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(%{}, claims)
    end

    test "returns empty for regular users" do
      claims = build(:claims, role: "user")

      assert %{results: [], aggregations: %{}, total: 0} = Search.search_jobs(%{}, claims)
    end

    test "accepts custom pagination" do
      claims = build(:claims, role: "admin")

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", request, _ ->
        assert %{from: 20, size: 10} = request
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(%{}, claims, 2, 10)
    end

    test "accepts custom sort" do
      claims = build(:claims, role: "admin")
      params = %{"sort" => ["created_at"]}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", request, _ ->
        assert %{sort: ["created_at"]} = request
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(params, claims)
    end

    test "accepts filters" do
      claims = build(:claims, role: "admin")
      params = %{"filters" => %{"status" => ["PENDING"]}}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{query: _}, _ ->
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(params, claims)
    end

    test "searches with query parameter" do
      claims = build(:claims, role: "admin")
      params = %{"query" => "test search"}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{query: _query}, _ ->
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(params, claims)
    end

    test "searches with query ending with quote" do
      claims = build(:claims, role: "admin")
      params = %{"query" => "test\""}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{query: _query}, _ ->
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(params, claims)
    end

    test "searches with query ending with parenthesis" do
      claims = build(:claims, role: "admin")
      params = %{"query" => "test)"}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{query: _query}, _ ->
        SearchHelpers.hits_response([])
      end)

      assert %{results: [], total: 0} = Search.search_jobs(params, claims)
    end
  end
end
