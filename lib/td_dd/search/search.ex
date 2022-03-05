defmodule TdDd.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdCache.TaxonomyCache
  alias TdDd.Search.Cluster

  require Logger

  def search(query), do: search(query, :structures)

  def search(query, index) when index in [:structures, :grants] do
    alias_name = Cluster.alias_name(index)
    response = Elasticsearch.post(Cluster, "/#{alias_name}/_search", query)

    case response do
      {:ok, %{"hits" => %{"hits" => results, "total" => total}} = res} ->
        aggregations = Map.get(res, "aggregations", %{})

        %{
          results: results,
          total: total,
          aggregations: maybe_format_aggregations(aggregations, index)
        }

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def search(body, query_params, index \\ :structures) do
    alias_name = Cluster.alias_name(index)
    url = "/#{alias_name}/_search"
    query_params = Map.take(query_params, ["scroll"])
    response = Elasticsearch.post(Cluster, url, body, params: query_params)

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
    response = Elasticsearch.post(Cluster, "_search/scroll", scroll_params)

    case response do
      {:ok, %{"_scroll_id" => scroll_id, "hits" => %{"hits" => results, "total" => total}} = res} ->
        aggregations = Map.get(res, "aggregations", %{})
        %{results: results, total: total, aggregations: aggregations, scroll_id: scroll_id}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query, index \\ :structures)

  def get_filters(query, index) do
    alias_name = Cluster.alias_name(index)
    response = Elasticsearch.post(Cluster, "/#{alias_name}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        {:ok, format_aggregations(aggregations)}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        {:error, error}
    end
  end

  defp maybe_format_aggregations(aggregations, :grants) do
    format_aggregations(aggregations)
  end

  defp maybe_format_aggregations(aggregations, _) do
    aggregations
  end

  defp format_aggregations(aggregations) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  defp filter_values({"taxonomy", %{"buckets" => buckets}}) do
    domains =
      buckets
      |> Enum.map(&bucket_key/1)
      |> Enum.map(&get_domain/1)

    {"taxonomy", domains}
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, Enum.map(buckets, &bucket_key/1)}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end

  defp filter_values({name, %{"doc_count" => 0}}), do: {name, []}

  defp bucket_key(%{"key_as_string" => key}) when key in ["true", "false"], do: key
  defp bucket_key(%{"key" => key}), do: key

  defp get_domain(id) when is_integer(id), do: TaxonomyCache.get_domain(id)
  defp get_domain(_), do: nil
end
