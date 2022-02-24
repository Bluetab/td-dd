defmodule Truedat.Search.Filters do
  @moduledoc """
  Support for building filtering search queries
  """

  alias Truedat.Search.Query

  def build_filters(filters, aggregations, acc \\ %{}) do
    filters
    |> Enum.map(&build_filter(&1, aggregations))
    |> Enum.reduce(acc, &merge/2)
  end

  defp merge({key, value}, %{} = acc) do
    Map.update(acc, key, value, fn existing ->
      [value | List.wrap(existing)]
    end)
  end

  defp build_filter({key, values}, aggs) do
    aggs
    |> Map.get(key, _field = key)
    |> build_filter(values)
  end

  defp build_filter(%{terms: %{field: field}}, values) do
    {:filter, Query.term_or_terms(field, values)}
  end

  defp build_filter(
         %{
           nested: %{path: path},
           aggs: %{distinct_search: %{terms: %{field: field}}}
         },
         values
       ) do
    nested_query = %{
      nested: %{
        path: path,
        query: Query.term_or_terms(field, values)
      }
    }

    {:filter, nested_query}
  end

  defp build_filter(field, values) when is_binary(field) do
    {:filter, Query.term_or_terms(field, values)}
  end
end
