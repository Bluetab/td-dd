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

  def search(body, query_params) do
    Logger.debug(fn -> "Query: #{inspect(body)} #{inspect(query_params)}" end)

    response =
      Elasticsearch.post(Cluster, "/#{@index}/_search?" <> URI.encode_query(query_params), body)

    case response do
      {:ok, %{"_scroll_id" => scroll_id, "hits" => %{"hits" => results, "total" => total}} = res} ->
        aggregations = Map.get(res, "aggregations", %{})
        %{results: results, total: total, aggregations: aggregations, scroll_id: scroll_id}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def scroll(scroll_params) do
    Logger.debug(fn -> "Scroll: #{inspect(scroll_params)}" end)
    response = Elasticsearch.post(Cluster, "/_search/scroll", scroll_params)

    case response do
      {:ok, %{"_scroll_id" => scroll_id, "hits" => %{"hits" => results, "total" => total}} = res} ->
        aggregations = Map.get(res, "aggregations", %{})
        %{results: results, total: total, aggregations: aggregations, scroll_id: scroll_id}

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
