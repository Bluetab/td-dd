defmodule TdDd.Search do
  @moduledoc """
  Search Engine calls
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Search.Cluster
  alias TdDd.Search.Store

  require Logger

  @index "structures"
  @index_config Application.get_env(:td_dd, TdDd.Search.Cluster, :indexes)

  def put_bulk_search(:all) do
    Index.hot_swap(Cluster, @index)
  end

  def put_bulk_search(ids) do
    %{bulk_page_size: bulk_page_size} =
      @index_config
      |> Keyword.get(:indexes)
      |> Map.get(:structures)

    ids
    |> Stream.chunk_every(bulk_page_size)
    |> Stream.map(&Store.list(&1))
    |> Stream.map(fn chunk ->
      time(bulk_page_size, fn ->
        bulk =
          chunk
          |> Enum.map(&Bulk.encode!(Cluster, &1, @index, "index"))
          |> Enum.join("")

        Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", bulk)
      end)
    end)
    |> Stream.run()
  end

  defp time(bulk_page_size, fun) do
    {millis, res} = Timer.time(fun)

    case millis do
      0 ->
        Logger.info("Indexing rate :infinity items/s")

      millis ->
        rate = div(1_000 * bulk_page_size, millis)
        Logger.info("Indexing rate #{rate} items/s")
    end

    res
  end

  # DELETE
  def delete_search(%DataStructure{versions: versions}) do
    Enum.each(versions, fn dsv -> Elasticsearch.delete_document(Cluster, dsv, @index) end)
  end

  def search(query) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"hits" => %{"hits" => results, "total" => total}} = res} ->
        aggregations = Map.get(res, "aggregations", %{})
        %{results: results, total: total, aggregations: aggregations}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query) do
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        aggregations
        |> Map.to_list()
        |> Enum.into(%{}, &filter_values/1)

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end
end
