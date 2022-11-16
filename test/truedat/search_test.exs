defmodule Truedat.SearchTest do
  use ExUnit.Case
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructureVersion
  alias Truedat.Search

  import Mox

  @moduletag sandbox: :shared

  @body %{"foo" => "bar"}
  @aggs %{"my_agg" => %{"buckets" => [%{"key" => "foo"}, %{"key" => "bar"}]}}
  @es6_total 123
  @es7_total %{"relation" => "eq", "value" => 123}

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.Cluster)
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "Search.search/3" do
    test "is compatible with Elasticsearch 6.x" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", body, opts ->
        assert opts == [params: %{"track_total_hits" => "true"}]
        assert body == @body
        SearchHelpers.hits_response([], @es6_total)
      end)

      assert Search.search(@body, "foo") == {:ok, %{results: [], total: 123}}
    end

    test "is compatible with Elasticsearch 7.x" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", body, opts ->
        assert opts == [params: %{"track_total_hits" => "true"}]
        assert body == @body
        SearchHelpers.hits_response([], @es7_total)
      end)

      assert Search.search(@body, "foo") == {:ok, %{results: [], total: 123}}
    end

    # TODO: Refactor to use scroll (TD-5342)
    test "sends multiple POST requests chunked every max_result_window" do
      max_result_window = 4
      dsvs = Enum.map(1..10, fn _ -> insert(:data_structure_version) end)
      [chunk_1, chunk_2, chunk_3] = Enum.chunk_every(dsvs, 4)

      body_post_while = %{
        size: max_result_window,
        foo: "bar"
      }

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: ^max_result_window, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_1, 10)

        assert length(hits) == max_result_window
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: ^max_result_window, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_2, 10)

        assert length(hits) == max_result_window
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: _, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_3, 10)

        assert length(hits) == 2
        hits_response
      end)

      {:ok, %{results: search_results}} =
        Search.search(
          %{page_size: max_result_window, max_results: 100},
          body_post_while,
          :structures,
          []
        )

      search_results_dsv_ds_ids = Enum.map(search_results, fn %{"id" => id} -> id end)

      dsv_ds_ids =
        Enum.map(dsvs, fn %DataStructureVersion{data_structure_id: data_structure_id} ->
          data_structure_id
        end)

      assert search_results_dsv_ds_ids == dsv_ds_ids
    end

    # TODO: Refactor to use scroll (TD-5342)
    test "sends multiple POST requests chunked every max_result_window, total is multiple of max_request_window" do
      max_result_window = 4
      total = max_result_window * 3
      dsvs = Enum.map(1..total, fn _ -> insert(:data_structure_version) end)
      [chunk_1, chunk_2, chunk_3] = Enum.chunk_every(dsvs, max_result_window)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: ^max_result_window, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_1, total)

        assert length(hits) == max_result_window
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: ^max_result_window, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_2, total)

        assert length(hits) == max_result_window
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: ^max_result_window, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_3, total)

        assert length(hits) == max_result_window
        hits_response
      end)

      {:ok, %{results: search_results}} =
        Search.search(
          %{page_size: max_result_window, max_results: total},
          %{size: :infinity, foo: "bar"},
          :structures,
          []
        )

      search_results_dsv_ds_ids = Enum.map(search_results, fn %{"id" => id} -> id end)

      dsv_ds_ids =
        Enum.map(dsvs, fn %DataStructureVersion{data_structure_id: data_structure_id} ->
          data_structure_id
        end)

      assert search_results_dsv_ds_ids == dsv_ds_ids
    end

    # TODO: Refactor to use scroll (TD-5342)
    test "send multiple POST requests chunked every max_result_window, limit by max_result_window_total" do
      max_result_window = 4
      total = 10
      dsvs = Enum.map(1..total, fn _ -> insert(:data_structure_version) end)
      [chunk_1, [chunk_2_element_0 | _tail_chunk_2], _chunk_3] = Enum.chunk_every(dsvs, 4)

      body_post_while = %{
        size: max_result_window,
        foo: "bar"
      }

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: ^max_result_window, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} = SearchHelpers.hits_response(chunk_1, total)

        assert length(hits) == max_result_window
        hits_response
      end)
      |> expect(:request, fn _, :post, "/structures/_search", body, _ ->
        assert %{size: _, foo: "bar"} = body

        hits_response =
          {:ok, %{"hits" => %{"hits" => hits}}} =
          SearchHelpers.hits_response([chunk_2_element_0], total)

        assert length(hits) == 1
        hits_response
      end)

      {:ok, %{results: search_results}} =
        Search.search(
          %{page_size: max_result_window, max_results: total},
          body_post_while,
          :structures,
          []
        )

      search_results_dsv_ds_ids = Enum.map(search_results, fn %{"id" => id} -> id end)

      dsv_ds_ids =
        dsvs
        |> Enum.take(5)
        |> Enum.map(fn %DataStructureVersion{data_structure_id: data_structure_id} ->
          data_structure_id
        end)

      assert search_results_dsv_ds_ids == dsv_ds_ids
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
      |> expect(:request, fn _, :post, "/foo/_search", _, _ ->
        SearchHelpers.aggs_response(@aggs, 123)
      end)

      assert Search.search(%{}, "foo") ==
               {:ok, %{aggregations: %{"my_agg" => ["foo", "bar"]}, results: [], total: 123}}
    end

    test "does not format aggregations from response if format: :raw is specified" do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", _, _ ->
        SearchHelpers.aggs_response(@aggs, 123)
      end)

      assert Search.search(%{}, "foo", format: :raw) ==
               {:ok, %{aggregations: @aggs, results: [], total: 123}}
    end

    test "enriches taxonomy aggregation" do
      %{id: parent_id} = CacheHelpers.insert_domain()
      %{id: domain_id} = CacheHelpers.insert_domain(parent_id: parent_id)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/foo/_search", _, _ ->
        SearchHelpers.aggs_response(%{
          "taxonomy" => %{"buckets" => [%{"key" => domain_id, "doc_count" => 12}]}
        })
      end)

      assert {:ok, %{aggregations: %{"taxonomy" => values}}} = Search.search(%{}, "foo")
      assert [%{id: _, external_id: _, parent_id: _, name: _}, %{id: _}] = values
    end
  end
end
