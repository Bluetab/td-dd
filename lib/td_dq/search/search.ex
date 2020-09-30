defmodule TdDq.Search do
  @moduledoc """
  Search Engine calls
  """
  alias TdDq.Search.Cluster

  require Logger

  def search(query, index) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = Elasticsearch.post(Cluster, "/#{index}/_search", query)

    case response do
      {:ok, %{"hits" => %{"hits" => results, "total" => total}, "aggregations" => aggregations}} ->
        %{results: results, aggregations: format_search_aggregations(aggregations), total: total}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query, index) do
    response = Elasticsearch.post(Cluster, "/#{index}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        format_search_aggregations(aggregations)

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  defp format_search_aggregations(aggregations) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end
end
