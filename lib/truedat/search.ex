defmodule Truedat.Search do
  @moduledoc """
  Performs search requests in the search engine and formats responses.
  """

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.Search.Query
  alias TdDd.Search.Cluster

  require Logger

  def search(%{page_size: page_size, max_results: max_results}, body, index, opts) do
    alias_name = Cluster.alias_name(index)

    results =
      Enum.reduce_while(
        1..max_results//page_size,
        [],
        fn _, results ->
          Logger.info(
            "Truedat.Search.post current results #{Enum.count(results)}}, getting #{page_size} more"
          )

          {:ok, %{results: page_results, total: total}} =
            body
            |> Query.maybe_add_search_after(results)
            |> Map.put(:size, page_size)
            |> post(alias_name, opts)

          acc_results = results ++ page_results

          if Enum.count(page_results) < page_size || Enum.count(acc_results) == total do
            {:halt, acc_results}
          else
            {:cont, acc_results}
          end
        end
      )

    {:ok, %{results: results}}
  end

  def search(body, index, opts \\ [])

  def search(%{size: :infinity} = body, index, opts) when is_atom(index) do
    %{"max_result_window" => page_size} = Cluster.setting(index)

    max_results = Application.get_env(:td_dd, __MODULE__)[:max_result_window_total]

    search(%{page_size: page_size, max_results: max_results}, body, index, opts)
  end

  def search(body, index, opts) when is_atom(index) do
    alias_name = Cluster.alias_name(index)
    search(body, alias_name, opts)
  end

  def search(body, index, opts) when is_binary(index) do
    post(body, index, opts)
  end

  defp post(body, index, opts) do
    search_opts = search_opts(opts[:params])

    Cluster
    |> Elasticsearch.post("/#{index}/_search", body, search_opts)
    |> format_response(opts[:format])
  end

  def scroll(body) do
    Cluster
    |> Elasticsearch.post("/_search/scroll", body)
    |> format_response()
  end

  def get_filters(body, index) do
    search(body, index, format: :aggs)
  end

  defp search_opts(%{"scroll" => _} = query_params) do
    [params: Map.take(query_params, ["scroll"])]
  end

  defp search_opts(_params) do
    []
  end

  defp format_response(response, format \\ nil)

  defp format_response({:ok, %{} = body}, format), do: {:ok, format_response(body, format)}

  defp format_response({:error, %{message: message} = error}, _) do
    Logger.warn("Error response from Elasticsearch: #{message}")
    {:error, error}
  end

  defp format_response(%{"aggregations" => aggs}, :aggs) do
    format_aggregations(aggs)
  end

  defp format_response(%{} = body, format) do
    body
    |> Map.take(["_scroll_id", "aggregations", "hits"])
    |> Enum.reduce(%{}, fn
      {"_scroll_id", scroll_id}, acc ->
        Map.put(acc, :scroll_id, scroll_id)

      {"aggregations", aggs}, acc ->
        Map.put(acc, :aggregations, format_aggregations(aggs, format))

      {"hits", %{"hits" => hits, "total" => total}}, acc ->
        acc
        |> Map.put(:results, hits)
        |> Map.put(:total, total)
    end)
  end

  defp format_aggregations(aggregations, format \\ nil)

  defp format_aggregations(aggregations, :raw), do: aggregations

  defp format_aggregations(aggregations, _) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  defp filter_values({"taxonomy", %{"buckets" => buckets}}) do
    domains =
      buckets
      |> Enum.flat_map(fn %{"key" => domain_id} ->
        TaxonomyCache.reaching_domain_ids(domain_id)
      end)
      |> Enum.uniq()
      |> Enum.map(&get_domain/1)
      |> Enum.reject(&is_nil/1)

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
