defmodule Truedat.Search do
  @moduledoc """
  Performs search requests in the search engine and formats responses.
  """

  alias TdCache.HierarchyCache
  alias TdCache.TaxonomyCache
  alias TdDd.Search.Cluster

  require Logger

  def search(body, index, opts \\ [])

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

  defp search_opts(_params), do: [params: %{"track_total_hits" => "true"}]

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
        |> Map.put(:total, get_total(total))
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

    {"taxonomy",
     %{
       type: :domain,
       values: domains
     }}
  end

  defp filter_values({name, %{"meta" => %{"type" => "domain"}, "buckets" => buckets}}) do
    domains =
      buckets
      |> Enum.map(fn %{"key" => domain_id} -> get_domain(domain_id) end)
      |> Enum.reject(&is_nil/1)

    {name,
     %{
       type: :domain,
       values: domains
     }}
  end

  defp filter_values({name, %{"meta" => %{"type" => "hierarchy"}, "buckets" => buckets}}) do
    node_names =
      buckets
      |> Enum.map(fn %{"key" => key} -> get_hierarchy_node(key) end)
      |> Enum.reject(&is_nil/1)

    {name,
     %{
       type: :hierarchy,
       values: node_names
     }}
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {
      name,
      %{
        values: Enum.map(buckets, &bucket_key/1),
        # TODO: This is a redundant as values is already in buckets, but don't
        # want to change front-end now.
        buckets: buckets
      }
    }
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end

  defp filter_values({name, %{"doc_count" => 0}}), do: {name, %{values: []}}

  defp bucket_key(%{"key_as_string" => key}) when key in ["true", "false"], do: key
  defp bucket_key(%{"key" => key}), do: key

  defp get_domain(id) when is_integer(id), do: TaxonomyCache.get_domain(id)
  defp get_domain(_), do: nil

  defp get_hierarchy_node(key) when is_binary(key) do
    case HierarchyCache.get_node!(key) do
      %{"name" => name} ->
        %{id: key, name: name}

      nil ->
        nil
    end
  end

  defp get_total(value) when is_integer(value), do: value
  defp get_total(%{"relation" => "eq", "value" => value}) when is_integer(value), do: value
end
