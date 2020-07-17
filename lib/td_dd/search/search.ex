defmodule TdDd.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdDd.Search.Cluster

  require Logger

  @index "structures"

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

  def search(query, scroll) do
    Logger.debug(fn -> "Query: #{inspect(query)} #{scroll}" end)
    response = Elasticsearch.post(Cluster, "/#{@index}/_search?scroll=#{scroll}", query)

    case response do
      {:ok, %{"_scroll_id" => scroll_id, "hits" => %{"hits" => hits, "total" => total}} = res} ->
        results = scroll_search(hits, hits, scroll_id, scroll)
        aggregations = Map.get(res, "aggregations", %{})
        %{results: results, total: total, aggregations: aggregations}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  defp scroll_search(results, [], _scroll_id, _scroll) do
    results
  end

  defp scroll_search(results, _hits, scroll_id, scroll) do
    query = %{scroll: scroll, scroll_id: scroll_id}
    response = Elasticsearch.post(Cluster, "/_search/scroll", query)

    case response do
      {:ok, %{"_scroll_id" => _scroll_id, "hits" => %{"hits" => []}}} ->
        results
      {:ok, %{"_scroll_id" => scroll_id, "hits" => %{"hits" => hits}}} ->
        scroll_search(results ++ hits, hits, scroll_id, scroll)
      err ->
        err
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
