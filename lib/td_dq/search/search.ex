defmodule TdDq.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdCache.TaxonomyCache
  alias TdDd.Search.Cluster

  require Logger

  def search(query, index) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    alias_name = Cluster.alias_name(index)
    response = Elasticsearch.post(Cluster, "/#{alias_name}/_search", query)

    case response do
      {:ok, %{"hits" => %{"hits" => results, "total" => total}, "aggregations" => aggregations}} ->
        %{results: results, aggregations: format_aggregations(aggregations), total: total}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query, index) do
    alias_name = Cluster.alias_name(index)
    response = Elasticsearch.post(Cluster, "/#{alias_name}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        format_aggregations(aggregations)

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  defp format_aggregations(aggregations) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  defp filter_values({"taxonomy", %{"buckets" => buckets}}) do
    domains =
      buckets
      |> Enum.map(& &1["key"])
      |> Enum.map(&TaxonomyCache.get_domain/1)

    {"taxonomy", domains}
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end

  defp filter_values({name, %{"doc_count" => 0}}), do: {name, []}
end
