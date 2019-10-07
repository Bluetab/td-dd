defmodule TdDq.Rules.Search do
  require Logger

  @moduledoc """
    Helper module to construct rule search queries.
  """
  alias TdDq.Accounts.User
  alias TdDq.Permissions
  alias TdDq.Search
  alias TdDq.Search.Aggregations
  alias TdDq.Search.Query

  def get_filter_values(%User{is_admin: true}, params) do
    filter_clause = Query.create_filters(params)
    query = Query.create_query(%{}, filter_clause)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def get_filter_values(%User{} = user, params) do
    user_defined_filters = Query.create_filters(params)

    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> rule_permissions(user_defined_filters)

    get_filter_values(permissions, params)
  end

  def get_filter_values([], _), do: %{}

  def get_filter_values(permissions, params) do
    user_defined_filters = Query.create_filters(params)
    user_defined_filters = user_defined_filters |> delete_execution_filter
    filter = Query.create_filter_clause(permissions, user_defined_filters)
    query = Query.create_query(params, filter)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def search(params, user, page \\ 0, size \\ 50)

  def search(params, %User{is_admin: true}, page, size) do
    filter_clause = Query.create_filters(params)
    filter_clause = filter_clause |> delete_execution_filter
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
    user_defined_filters = Query.create_filters(params)

    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> rule_permissions(user_defined_filters)

    filter_rules(params, permissions, page, size)
  end

  defp rule_permissions(domain_permissions, user_defined_filters) do
    domain_permissions
    |> Enum.filter(fn permissions_obj ->
      case do_rules_execution(user_defined_filters) do
        true ->
          check_execute_and_view_permission(permissions_obj)

        false ->
          Enum.any?(permissions_obj.permissions, &check_view_or_manage_permission(&1))
      end
    end)
  end

  defp check_execute_and_view_permission(permissions_obj) do
    Enum.member?(permissions_obj.permissions, :execute_quality_rule) &&
      Enum.member?(permissions_obj.permissions, :view_quality_rule)
  end

  defp check_view_or_manage_permission(permission_names) do
    permission_names == :view_quality_rule ||
      permission_names == :manage_confidential_business_concepts
  end

  defp filter_rules(_params, [], _page, _size),
    do: %{results: [], aggregations: %{}, total: 0}

  defp filter_rules(params, [_h | _t] = permissions, page, size) do
    user_defined_filters = Query.create_filters(params)
    user_defined_filters = user_defined_filters |> delete_execution_filter
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
      Search.search(search)

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

  defp do_rules_execution(user_defined_filters) do
    user_defined_filters
    |> Enum.filter(&Enum.at(Map.get(get_filter(&1), "execution.raw", []), 0))
    |> Enum.empty?()
    |> Kernel.!()
  end

  defp delete_execution_filter(user_defined_filters) do
    user_defined_filters
    |> Enum.filter(&(!Enum.at(Map.get(get_filter(&1), "execution.raw", []), 0)))
  end

  defp get_filter(%{terms: field}), do: field
  defp get_filter(_), do: %{}
end
