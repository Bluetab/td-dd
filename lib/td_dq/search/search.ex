defmodule TdDq.Search do
  @moduledoc """
  Search Engine calls
  """

  alias Jason, as: JSON
  alias TdDq.ESClientApi

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
    bulk =
      ids 
      |> Enum.map(&Bulk.encode!(Cluster, %Indexable{id: &1}, @index, "delete"))
      |> Enum.join("")

    Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", bulk)
  end

  # CREATE AND UPDATE
  def put_searchable(searchable) do
    search_fields = searchable.__struct__.search_fields(searchable)
    index_name = searchable.__struct__.index_name()

    response =
      ESClientApi.index_content(
        index_name,
        searchable.id,
        search_fields |> JSON.encode!()
      )

    case response do
      {:ok, %HTTPoison.Response{status_code: _}} ->
        Logger.info("Item on #{index_name} was created/updated")

      {:error, _error} ->
        Logger.error("ES: Error creating/updating Item on #{index_name}")
    end
  end

  def delete(index_name, ids) when is_list(ids) do
    Enum.map(ids, &delete(index_name, &1))
  end

  def delete(index_name, id) do
    response = ESClientApi.delete_content(index_name, id)

    case response do
      {_, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Item #{id} on #{index_name} deleted status 200")

      {_, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("ES: Error deleting item #{id} on #{index_name} status #{status_code}")

      {:error, %HTTPoison.Error{reason: :econnrefused}} ->
        Logger.error("Error connecting to ES")
    end
  end

  def search(index_name, query) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = ESClientApi.search_es(index_name, query)

    case response do
      {:ok,
       %HTTPoison.Response{
         body: %{"hits" => %{"hits" => results, "total" => total}, "aggregations" => aggregations}
       }} ->
        %{results: results, aggregations: format_search_aggegations(aggregations), total: total}

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  def get_filters(index_name, query) do
    response = ESClientApi.search_es(index_name, query)

    case response do
      {:ok, %HTTPoison.Response{body: %{"aggregations" => aggregations}}} ->
        aggregations
        |> format_search_aggegations()

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  defp format_search_aggegations(aggregations) do
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
