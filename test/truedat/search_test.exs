defmodule Truedat.SearchTest do
  use ExUnit.Case

  alias Truedat.Search

  import Mox

  @body %{"foo" => "bar"}
  @aggs %{"my_agg" => %{"buckets" => [%{"key" => "foo"}, %{"key" => "bar"}]}}

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  describe "Search.search/3" do
    test "sends a POST request" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", body, [] ->
        assert body == @body
        SearchHelpers.hits_response([], 123)
      end)

      assert Search.search(@body, "foo") == {:ok, %{results: [], total: 123}}
    end

    test "translates atom to index alias" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, _ ->
        SearchHelpers.hits_response([])
      end)
      |> expect(:request, fn _, :post, "/rules/_search", _, _ ->
        SearchHelpers.hits_response([])
      end)
      |> expect(:request, fn _, :post, "/implementations/_search", _, _ ->
        SearchHelpers.hits_response([])
      end)
      |> expect(:request, fn _, :post, "/grants/_search", _, _ ->
        SearchHelpers.hits_response([])
      end)
      |> expect(:request, fn _, :post, "/jobs/_search", _, _ ->
        SearchHelpers.hits_response([])
      end)

      assert {:ok, _} = Search.search(@body, :structures)
      assert {:ok, _} = Search.search(@body, :rules)
      assert {:ok, _} = Search.search(@body, :implementations)
      assert {:ok, _} = Search.search(@body, :grants)
      assert {:ok, _} = Search.search(@body, :jobs)
    end

    test "formats aggregation values from response" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", _, [] ->
        SearchHelpers.aggs_response(@aggs, 123)
      end)

      assert Search.search(%{}, "foo") ==
               {:ok, %{aggregations: %{"my_agg" => ["foo", "bar"]}, results: [], total: 123}}
    end

    test "does not format aggregations from response if format: :raw is specified" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", _, [] ->
        SearchHelpers.aggs_response(@aggs, 123)
      end)

      assert Search.search(%{}, "foo", format: :raw) ==
               {:ok, %{aggregations: @aggs, results: [], total: 123}}
    end

    test "enriches taxonomy aggregation" do
      %{id: parent_id} = CacheHelpers.insert_domain()
      %{id: domain_id} = CacheHelpers.insert_domain(parent_id: parent_id)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", _, [] ->
        SearchHelpers.aggs_response(%{
          "taxonomy" => %{"buckets" => [%{"key" => domain_id, "doc_count" => 12}]}
        })
      end)

      assert {:ok, %{aggregations: %{"taxonomy" => values}}} = Search.search(%{}, "foo")
      assert [%{id: _, external_id: _, parent_id: _, name: _}, %{id: _}] = values
    end
  end
end
