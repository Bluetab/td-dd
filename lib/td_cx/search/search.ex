defmodule TdCx.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdDd.Search.Cluster

  require Logger

  @index "jobs"

  def search(query) do
    response =
      Elasticsearch.post(Cluster, "/#{@index}/_search", query,
        params: %{"track_total_hits" => "true"}
      )

    case response do
      {:ok, %{"aggregations" => aggregations, "hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: get_total(total), aggregations: aggregations}

      {:ok, %{"hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: get_total(total), aggregations: %{}}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query) do
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        aggs =
          aggregations
          |> Map.to_list()
          |> Enum.into(%{}, &filter_values/1)

        {:ok, aggs}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        {:error, error}
    end
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, %{values: Enum.map(buckets, & &1["key"])}}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end

  defp filter_values({name, %{"doc_count" => 0}}), do: {name, %{values: []}}

  defp get_total(value) when is_integer(value), do: value
  defp get_total(%{"relation" => "eq", "value" => value}) when is_integer(value), do: value
end
