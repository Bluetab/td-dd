defmodule TdDq.Rules.Search do
  require Logger

  @moduledoc """
    Helper module to construct rule search queries.
  """
  alias TdDq.Search.Aggregations
  alias TdDq.Search.Query

  @search_service Application.get_env(:td_dq, :elasticsearch)[:search_service]

  def search(params, page, size) do
    filter_clause = Query.create_filters(params)
    query = Query.create_query(params, filter_clause)

    sort = Map.get(params, "sort", ["name.raw"])

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort,
      aggs: Aggregations.aggregation_terms()
    }
    |> do_search
  end

  defp do_search(search) do
    %{results: results, aggregations: aggregations, total: total} =
      @search_service.search("quality_rule", search)

    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(&atomize_keys/1)

    %{results: results, aggregations: aggregations, total: total}
  end

  defp atomize_keys(%{} = map) do
    map
    |> Enum.into(%{}, fn {k, v} -> {atomize_key(k), atomize_keys(v)} end)
  end
  defp atomize_keys(value), do: value

  defp atomize_key(key) when is_binary(key), do: String.to_atom(key)
  defp atomize_key(key), do: key
end
