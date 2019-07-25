defmodule TdDq.Rules.Search do
  require Logger

  @moduledoc """
    Helper module to construct rule search queries.
  """
  alias TdDq.Accounts.User
  alias TdDq.Permissions
  alias TdDq.Search.Aggregations
  alias TdDq.Search.Query

  @search_service Application.get_env(:td_dq, :elasticsearch)[:search_service]

  def get_filter_values(params) do
    filter_clause = Query.create_filters(params)
    query = Query.create_query(%{}, filter_clause)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    @search_service.get_filters("quality_rule", search)
  end

  def search(params, user, page \\ 0, size \\ 50)

  def search(params, %User{is_admin: true}, page, size) do
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

  def search(params, %User{} = user, page, size) do
    permissions = Permissions.get_domain_permissions(user)
    filter_rules(params, permissions, page, size)
  end

  defp filter_rules(_params, [], _page, _size),
    do: %{results: [], aggregations: %{}, total: 0}

  defp filter_rules(params, [_h | _t] = permissions, page, size) do
    user_defined_filters = Query.create_filters(params)
    filter = Query.create_filter_clause(permissions, user_defined_filters)

    query = Query.create_query(params, filter)

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
