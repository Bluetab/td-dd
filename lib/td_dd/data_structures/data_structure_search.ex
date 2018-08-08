defmodule TdDd.DataStructure.Search do
  require Logger

  @moduledoc """
    Helper module to construct business concept search queries.
  """
  alias TdDd.Search.Aggregations
  alias TdDd.Utils.CollectionUtils

  @search_service Application.get_env(:td_dd, :elasticsearch)[:search_service]

  def search_data_structures(params, page \\ 0, size \\ 50)

  def search_data_structures(params, page, size) do
    filter_clause = create_filters(params)

    query =
      case filter_clause do
        [] -> create_query(params)
        _ -> create_query(params, filter_clause)
      end

    search = %{from: page * size, size: size, query: query}

    %{results: results, total: total} = @search_service.search("data_structure", search)

    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(fn ds ->
        CollectionUtils.atomize_keys(
          Map.put(
            ds,
            "last_change_by",
            CollectionUtils.atomize_keys(Map.get(ds, "last_change_by"))
          )
        )
      end)
      |> Enum.map(fn ds ->
        CollectionUtils.atomize_keys(
          Map.put(
            ds,
            "data_fields",
            Enum.map(ds.data_fields, fn df ->
              CollectionUtils.atomize_keys(df)
            end)
          )
        )
      end)

    %{results: results, total: total}
  end

  def create_filters(%{"filters" => filters}) do
    filters
    |> Map.to_list()
    |> Enum.map(&to_terms_query/1)
  end

  def create_filters(_), do: []

  defp to_terms_query({filter, values}) do
    Aggregations.aggregation_terms()
    |> Map.get(filter)
    |> get_filter(values, filter)
  end

  defp get_filter(%{terms: %{field: field}}, values, _) do
    %{terms: %{field => values}}
  end

  defp create_query(%{"query" => query}) do
    %{simple_query_string: %{query: query}}
    |> bool_query
  end

  defp create_query(_params) do
    %{match_all: %{}}
    |> bool_query
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
end
