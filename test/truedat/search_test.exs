defmodule Truedat.SearchTest do
  # use ExUnit.Case
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructureVersion
  alias Truedat.Search

  import Mox

  @body %{"foo" => "bar"}
  @aggs %{"my_agg" => %{"buckets" => [%{"key" => "foo"}, %{"key" => "bar"}]}}
  @moduletag sandbox: :shared

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    start_supervised!(TdDd.Search.StructureEnricher)
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

    test "sends multiple POST requests if query size is :infinity" do
      max_result_window = 4
      dsvs = Enum.map(1..10, fn _ -> insert(:data_structure_version) end)
      [chunk_1, chunk_2, chunk_3] = Enum.chunk_every(dsvs, 4)

      body_post_while = %{
        size: max_result_window,
        foo: "bar"
      }

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", body, [] ->
        assert %{size: 4, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_1, 10)

        assert length(hits) == 4
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, [] ->
        assert %{size: 4, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_2, 10)

        assert length(hits) == 4
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, [] ->
        assert %{size: 4, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_3, 10)

        assert length(hits) == 2
        hits_response
      end)

      {:ok, %{results: search_results}} =
        Search.post_while(
          body_post_while,
          :structures,
          [],
          max_result_window,
          max_result_window,
          %{results: [], total: 0}
        )

      search_results_dsv_names =
        Enum.map(search_results, fn %{"_source" => %{"name" => name}} -> name end)

      dsv_names = Enum.map(dsvs, fn %DataStructureVersion{name: name} -> name end)

      assert search_results_dsv_names == dsv_names
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
