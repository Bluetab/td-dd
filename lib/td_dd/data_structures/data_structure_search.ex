defmodule TdDd.DataStructure.Search do
  require Logger

  @moduledoc """
    Helper module to construct business concept search queries.
  """
  alias TdDd.Accounts.User
  alias TdDd.DataStructure.Query
  alias TdDd.Permissions
  alias TdDd.Search.Aggregations
  alias TdDd.Utils.CollectionUtils

  @search_service Application.get_env(:td_dd, :elasticsearch)[:search_service]

  def get_filter_values(%User{is_admin: true}) do
    query = %{} |> create_query
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    @search_service.get_filters(search)
  end

  def get_filter_values(%User{} = user) do
    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, :view_data_structure))
    get_filter_values(permissions)
  end

  def get_filter_values([]), do: %{}

  def get_filter_values(permissions) do
    filter = permissions |> create_filter_clause
    query = %{} |> create_query(filter)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    @search_service.get_filters(search)
  end

  def search_data_structures(params, user, page \\ 0, size \\ 50)

  def search_data_structures(params, %User{is_admin: true}, page, size) do
    filter_clause = create_filters(params)

    query =
      case filter_clause do
        [] -> create_query(params)
        _ -> create_query(params, filter_clause)
      end

    %{from: page * size, size: size, query: query}
    |> do_search
  end

  #Non-admin search
  def search_data_structures(params, %User{} = user, page, size) do
    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, :view_data_structure))

    filter_data_structures(params, permissions, page, size)
  end

  defp filter_data_structures(_params, [], _page, _size), do: []

  defp filter_data_structures(params, [_h | _t] = permissions, page, size) do
    user_defined_filters = create_filters(params)

    filter = permissions |> create_filter_clause(user_defined_filters)

    query = create_query(params, filter)
    %{from: page * size, size: size, query: query}
      |> do_search
  end

  defp create_filter_clause(permissions, user_defined_filters \\ []) do
    should_clause =
      permissions
      |> Enum.map(&entry_to_filter_clause(&1, user_defined_filters))

    %{bool: %{should: should_clause}}
  end

  defp entry_to_filter_clause(
         %{resource_id: resource_id, permissions: _},
         user_defined_filters
       ) do

    domain_clause = %{term: %{domain_ids: resource_id}}

    %{
      bool: %{filter: user_defined_filters ++ [domain_clause]}
    }
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
    equery = Query.add_query_wildcard(query)
    %{simple_query_string: %{query: equery}}
    |> bool_query
  end

  defp create_query(%{"query" => query}, filter) do
    equery = Query.add_query_wildcard(query)
    %{simple_query_string: %{query: equery}}
    |> bool_query(filter)
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

  defp do_search(search) do
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
end
