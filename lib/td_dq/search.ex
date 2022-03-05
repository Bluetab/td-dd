defmodule TdDq.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdCache.TaxonomyCache
  alias TdDd.Search.Cluster

  require Logger

  def search(query, index) do
    alias_name = Cluster.alias_name(index)
    response = Elasticsearch.post(Cluster, "/#{alias_name}/_search", query)

    case response do
      {:ok, %{"hits" => %{"hits" => results, "total" => total}, "aggregations" => aggregations}} ->
        %{results: results, aggregations: format_aggregations(aggregations), total: total}

      {:ok, %{"hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: total}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def search(query, query_params, index) do
    alias_name = Cluster.alias_name(index)

    params = Map.take(query_params, ["scroll"])
    response = Elasticsearch.post(Cluster, "/#{alias_name}/_search", query, params: params)

    case response do
      {:ok, %{} = body} ->
        Enum.reduce(body, %{}, fn
          {"_scroll_id", scroll_id}, acc ->
            Map.put(acc, :scroll_id, scroll_id)

          {"hits", %{"hits" => hits, "total" => total}}, acc ->
            acc
            |> Map.put(:total, total)
            |> Map.put(:results, hits)

          {"aggregations", aggregations}, acc ->
            Map.put(acc, :aggregations, format_aggregations(aggregations))

          _, acc ->
            acc
        end)

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def scroll(scroll_params) do
    [opts, scroll_params] =
      scroll_params
      |> Map.take(["opts"])
      |> case do
        %{"opts" => opts} ->
          [opts, Map.drop(scroll_params, ["opts"])]

        %{} ->
          [[], scroll_params]
      end

    response = Elasticsearch.post(Cluster, "_search/scroll", scroll_params, opts)

    case response do
      {:ok, %{"_scroll_id" => scroll_id, "hits" => %{"hits" => results, "total" => total}} = res} ->
        aggregations = Map.get(res, "aggregations", %{})
        %{results: results, total: total, aggregations: aggregations, scroll_id: scroll_id}

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
        {:ok, format_aggregations(aggregations)}

      {:ok, %{"hits" => %{"hits" => results, "total" => total}}} ->
        {:ok, %{results: results, total: total, aggregations: %{}}}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        {:error, error}
    end
  end

  defp format_aggregations(aggregations) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  # TODO: Avoid repeated code... most of this is also in TdDd.Search
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
