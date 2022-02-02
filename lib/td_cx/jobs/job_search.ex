defmodule TdCx.Jobs.Search do
  @moduledoc """
  Helper module to construct job search queries.
  """

  alias TdCx.Auth.Claims
  alias TdCx.Search
  alias TdCx.Search.Aggregations
  alias TdCx.Sources.Query

  def get_filter_values(%Claims{role: role}, params) when role in ["admin", "service"] do
    filter_clause = create_filters(params)
    query = %{bool: %{filter: filter_clause}}
    search = %{query: query, aggs: Aggregations.aggregation_terms(), size: 0}
    Search.get_filters(search)
  end

  def get_filter_values(_, _), do: %{}

  def search_jobs(params, claims, page \\ 0, size \\ 50)

  # Admin or service account search, no filters applied
  def search_jobs(params, %Claims{role: role}, page, size) when role in ["admin", "service"] do
    filter_clause = create_filters(params)

    query =
      case filter_clause do
        [] -> create_query(params)
        _ -> create_query(params, filter_clause)
      end

    sort = Map.get(params, "sort", ["_score", "external_id.raw"])

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort,
      aggs: Aggregations.aggregation_terms()
    }
    |> do_search
  end

  def search_jobs(_params, _claims, _page, _size),
    do: %{results: [], aggregations: %{}, total: 0}

  defp create_filters(%{"filters" => filters}) do
    filters
    |> Map.to_list()
    |> Enum.map(&to_terms_query/1)
  end

  defp create_filters(_), do: []

  defp to_terms_query({filter, values}) do
    Aggregations.aggregation_terms()
    |> Map.get(filter)
    |> get_filter(values, filter)
  end

  defp get_filter(%{terms: %{field: field}}, values, _) do
    %{terms: %{field => values}}
  end

  defp get_filter(nil, values, filter) when is_list(values) do
    %{terms: %{filter => values}}
  end

  defp get_filter(nil, value, filter) when not is_list(value) do
    %{term: %{filter => value}}
  end

  defp get_filter(_, _, _), do: nil

  defp create_query(%{business_concept_id: id}) do
    %{term: %{business_concept_id: id}}
  end

  defp create_query(%{"query" => query}) do
    equery = Query.add_query_wildcard(query)

    %{simple_query_string: %{query: equery}}
    |> bool_query
  end

  defp create_query(_params) do
    %{match_all: %{}}
    |> bool_query
  end

  defp create_query(%{"query" => query}, filter) do
    equery = Query.add_query_wildcard(query)

    %{simple_query_string: %{query: equery}}
    |> bool_query(filter)
  end

  defp create_query(_params, filter) do
    %{match_all: %{}}
    |> bool_query(filter)
  end

  defp bool_query(query, filter) do
    %{bool: %{must: query, filter: filter}}
  end

  defp bool_query(query) do
    %{bool: %{must: query}}
  end

  defp do_search(search) do
    %{results: results, total: total} = Search.search(search)
    results = results |> Enum.map(&Map.get(&1, "_source"))
    %{results: results, total: total}
  end
end
