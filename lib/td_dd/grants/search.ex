defmodule TdDd.Grants.Search do
  @moduledoc """
  The Grants Search context
  """

  alias TdDd.Auth.Claims
  alias TdDd.Permissions
  alias TdDd.Search
  alias TdDd.Search.Query

  require Logger

  @index :grants


  def get_filter_values(claims, permission, params)

  def get_filter_values(%Claims{role: role}, _permission, params)
      when role in ["admin", "service"] do
    IO.puts("GET_FILTER_VALUES (%Claims{role: role}, _permission, params) when role in")
    filter_clause = Query.create_filters(params, @index)
    query = Query.create_query(%{}, filter_clause)
    search = %{query: query, aggs: Query.get_aggregation_terms(@index)}
    Search.get_filters(search, @index)
  end

  def get_filter_values(%Claims{} = claims, permission, params) do
    IO.puts("GET_FILTER_VALUES(%Claims{} = claims, permission, params)")
    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, permission))

    get_filter_values(permissions, params)
  end

  def get_filter_values([], _params), do: %{}

  def get_filter_values(permissions, params) do
    IO.puts("GET_FILTER_VALUES(permissions, params)")
    user_defined_filters = Query.create_filters(params, @index)
    filter = permissions |> Query.create_filter_clause(user_defined_filters)
    query = Query.create_query(%{}, filter)
    search = %{query: query, aggs: Query.get_aggregation_terms(@index)}
    Search.get_filters(search, @index)
  end

  def search(params, claims, page \\ 0, size \\ 50, index \\ :grants)

  def search(params, %Claims{role: role}, page, size, index) when role in ["admin", "service"] do
    IO.puts("SEARCH ADMIN TdDd.Grants.Search")
    filter_clause = Query.create_filters(params, index)
    query = Query.create_query(params, filter_clause)
    sort = Map.get(params, "sort", default_sort(index))

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort,
      aggs: Query.get_aggregation_terms(index)
    }
    |> do_search(index)
  end

  def search(params, %Claims{} = claims, page, size, index) do
    # user_defined_filters = Query.create_filters(params, index)
    IO.puts("SEARCH USER TdDd.Grants.Search")

    permissions =
      claims
      |> Permissions.get_domain_permissions() |> IO.inspect(label: "permissions")
      |> get_permissions() |> IO.inspect(label: "get_permissions")

    filter(params, permissions, page, size, index)
  end

  defp get_filters(permissions, params, index) do
    IO.puts("GET_FILTERS TdDd.Grants.Search")
    user_defined_filters = Query.create_filters(params, index)
    filter = Query.create_filter_clause(permissions, user_defined_filters)
    query = Query.create_query(params, filter)
    search = %{query: query, aggs: Query.get_aggregation_terms(index)}
    Search.get_filters(search, index)
  end

  def default_sort(:grants), do: ["_id"]

  defp get_permissions(domain_permissions) do
    Enum.filter(domain_permissions, fn %{permissions: permissions} ->
      Enum.any?(permissions, &check_view_or_manage_permission(&1))
    end)
  end

  defp check_view_or_manage_permission(permission_names) do
    permission_names == :view_grants ||
      permission_names == :manage_grants
  end

  defp filter(_params, [], _page, _size, _index),
    do: %{results: [], aggregations: %{}, total: 0}

  defp filter(params, [_h | _t] = permissions, page, size, index) do
    IO.puts("FILTER TdDd.Grants.Search")
    user_defined_filters = Query.create_filters(params |> IO.inspect(label: "params"), index) |> IO.inspect(label: "user_defined_filters")
    filter = Query.create_filter_clause(permissions, user_defined_filters)
    query = Query.create_query(params, filter) |> IO.inspect(label: "query")
    sort = Map.get(params, "sort", default_sort(index))

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort,
      aggs: Query.get_aggregation_terms(index)
    }
    |> do_search(index)
  end

  defp do_search(search, index) do

    IO.puts("DO_SEARCH")
    %{results: results, aggregations: aggregations, total: total} = Search.search(search, index)

    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(&Map.Helpers.atomize_keys/1)

    %{results: results, aggregations: aggregations, total: total}
  end
end
