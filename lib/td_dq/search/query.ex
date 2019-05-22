defmodule TdDq.Search.Query do
  @moduledoc """
    Helper module to manipulate elastic search queries.
  """
  alias TdDq.Search.Aggregations

  def create_filters(%{"filters" => filters}) do
    filters
    |> Map.to_list()
    |> Enum.map(&to_terms_query/1)
  end
  def create_filters(_), do: []

  defp to_terms_query({filter, values}) do
    Aggregations.aggregation_terms()
    |> Map.get(filter)
    |> get_filter(values)
  end

  defp get_filter(%{terms: %{field: field}}, values) do
    %{terms: %{field => values}}
  end

  defp get_filter(%{aggs: %{distinct_search: distinct_search}, nested: %{path: path}}, values) do
    %{nested: %{path: path, query: build_nested_query(distinct_search, values)}}
  end

  defp build_nested_query(%{terms: %{field: field}}, values) do
    %{terms: %{field => values}} |> bool_query([])
  end

  def create_query(%{"query" => query}, filter) do
    equery = add_query_wildcard(query)

    %{simple_query_string: %{query: equery}}
    |> bool_query(filter)
  end
  def create_query(_params, filter) do
    %{match_all: %{}}
    |> bool_query(filter)
  end

  defp bool_query(query, []), do: %{bool: %{must: query}}
  defp bool_query(query, filter), do: %{bool: %{must: query, filter: filter}}

  def add_query_wildcard(query) do
    case String.last(query) do
      nil -> query
      "\"" -> query
      ")" -> query
      " " -> query
      _ -> "#{query}*"
    end
  end
end
