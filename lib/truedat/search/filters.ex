defmodule Truedat.Search.Filters do
  @moduledoc """
  Support for building filtering search queries
  """

  alias TdCache.TaxonomyCache
  alias Truedat.Search.Query

  def build_filters(filters, aggregations, acc, filter_type \\ :filters) do
    filters
    |> Enum.map(&build_filter(&1, aggregations, filter_type))
    |> Enum.reduce(acc, &merge/2)
  end

  defp merge({key, [value]}, %{} = acc) do
    Map.update(acc, key, [value], fn existing ->
      [value | List.wrap(existing)]
    end)
  end

  defp merge({key, value}, %{} = acc) do
    Map.update(acc, key, value, fn existing ->
      [value | List.wrap(existing)]
    end)
  end

  defp build_filter({"taxonomy" = key, values}, aggs, filter_type) do
    values = TaxonomyCache.reachable_domain_ids(values)
    build_filter(key, values, aggs, filter_type)
  end

  defp build_filter({key, values}, aggs, filter_type) do
    build_filter(key, values, aggs, filter_type)
  end

  defp build_filter(%{terms: %{field: field}}, values, filter_type) do
    must_or_filter = get_filter_type(filter_type)
    {must_or_filter, term(field, values)}
  end

  defp build_filter(
         %{
           nested: %{path: path},
           aggs: %{distinct_search: %{terms: %{field: field}}}
         },
         values,
         filter_type
       ) do
    nested_query = %{
      nested: %{
        path: path,
        query: term(field, values)
      }
    }

    must_or_filter = get_filter_type(filter_type)
    {must_or_filter, nested_query}
  end

  defp build_filter("must_not", values, _filter_type) do
    {:must_not, Enum.map(values, fn {key, term_values} -> term(key, term_values) end)}
  end

  defp build_filter("exists", value, _filter_type) do
    {:must, %{exists: value}}
  end

  defp build_filter(field, value, filter_type)
       when field in ["updated_at", "start_date", "end_date"] do
    must_or_filter = get_filter_type(filter_type)
    {must_or_filter, Query.range(field, value)}
  end

  defp build_filter(field, values, filter_type) when is_binary(field) do
    must_or_filter = get_filter_type(filter_type)
    {must_or_filter, term(field, values)}
  end

  defp build_filter(key, values, aggs, filter_type) do
    aggs
    |> Map.get(key, _field = key)
    |> build_filter(values, filter_type)
  end

  defp term(field, values) do
    Query.term_or_terms(field, values)
  end

  defp get_filter_type(:must), do: :must
  defp get_filter_type(:filters), do: :filter
  defp get_filter_type(:must_not), do: :must_not
end
