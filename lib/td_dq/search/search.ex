defmodule TdDq.Search do
  @moduledoc """
  Search Engine calls
  """
  alias Elasticsearch.Index.Bulk
  alias TdDq.Rules.Indexable
  alias TdDq.Search.Cluster

  require Logger

  @index "rules"

  def put_bulk_search(:rule) do
    Elasticsearch.Index.hot_swap(Cluster, @index)
  end

  def put_bulk_search(rules, :rule) do
    bulk =
      rules
      |> Enum.map(&Bulk.encode!(Cluster, &1, @index, "index"))
      |> Enum.join("")

    Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", bulk)
  end

  def put_bulk_delete(ids, :rule) do
    Enum.map(ids, &Elasticsearch.delete_document(Cluster, %Indexable{rule: %{id: &1}}, @index))
  end

  def search(query) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"hits" => %{"hits" => results, "total" => total}, "aggregations" => aggregations}} ->
        %{results: results, aggregations: format_search_aggregations(aggregations), total: total}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query) do
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

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
