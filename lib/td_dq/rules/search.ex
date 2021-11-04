defmodule TdDq.Rules.Search do
  @moduledoc """
  The Rules Search context
  """

  alias TdDq.Auth.Claims
  alias TdDq.Permissions
  alias TdDq.Search
  alias TdDq.Search.Query

  require Logger

  def get_filter_values(claims, params, index \\ :rules)

  def get_filter_values(%Claims{role: role}, params, index) when role in ["admin", "service"] do
    filter_clause = Query.create_filters(params, index)
    query = Query.create_query(%{}, filter_clause)
    search = %{query: query, aggs: Query.get_aggregation_terms(index)}
    Search.get_filters(search, index)
  end

  def get_filter_values(%Claims{} = claims, params, index) do
    user_defined_filters = Query.create_filters(params, index)

    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> get_permissions(user_defined_filters, index)

    get_filters(permissions, params, index)
  end

  def scroll_implementations(%{"scroll_id" => _, "scroll" => _} = scroll_params) do
    scroll_params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  def search(params, claims, page \\ 0, size \\ 50, index \\ :rules)

  def search(params, %Claims{role: role}, page, size, index) when role in ["admin", "service"] do
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
    |> do_search(index, params)
  end

  def search(params, %Claims{} = claims, page, size, index) do
    user_defined_filters = Query.create_filters(params, index)

    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> get_permissions(user_defined_filters, index)

    filter(params, permissions, page, size, index)
  end

  defp get_filters([], _, _index), do: %{}

  defp get_filters(permissions, params, index) do
    user_defined_filters = Query.create_filters(params, index)
    filter = Query.create_filter_clause(permissions, user_defined_filters)
    query = Query.create_query(params, filter)
    search = %{query: query, aggs: Query.get_aggregation_terms(index)}
    Search.get_filters(search, index)
  end

  defp default_sort(:rules), do: ["name.raw"]

  defp default_sort(:implementations), do: ["implementation_key.raw"]

  defp get_permissions(domain_permissions, user_defined_filters, index) do
    case index do
      :rules -> get_permissions(domain_permissions)
      :implementations -> get_permissions(domain_permissions, user_defined_filters)
    end
  end

  defp get_permissions(domain_permissions, user_defined_filters) do
    Enum.filter(domain_permissions, fn permissions_obj ->
      case do_rules_execution(user_defined_filters) do
        true ->
          check_execute_and_view_permission(permissions_obj)

        false ->
          Enum.any?(permissions_obj.permissions, &check_view_or_manage_permission(&1))
      end
    end)
  end

  defp get_permissions(domain_permissions) do
    Enum.filter(domain_permissions, fn %{permissions: permissions} ->
      Enum.any?(permissions, &check_view_or_manage_permission(&1))
    end)
  end

  defp check_execute_and_view_permission(permissions_obj) do
    Enum.member?(permissions_obj.permissions, :execute_quality_rule_implementations) &&
      Enum.any?(permissions_obj.permissions, &check_view_or_manage_permission(&1))
  end

  defp check_view_or_manage_permission(permission_names) do
    permission_names == :view_quality_rule ||
      permission_names == :manage_confidential_business_concepts
  end

  defp filter(_params, [], _page, _size, _index),
    do: %{results: [], aggregations: %{}, total: 0}

  defp filter(params, [_h | _t] = permissions, page, size, index) do
    user_defined_filters = Query.create_filters(params, index)
    filter = Query.create_filter_clause(permissions, user_defined_filters)
    query = Query.create_query(params, filter)
    sort = Map.get(params, "sort", default_sort(index))

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort,
      aggs: Query.get_aggregation_terms(index)
    }
    |> do_search(index, params)
  end

  defp do_search(search, index, params) do
    params
    |> Map.take(["scroll"])
    |> case do
      %{"scroll" => _scroll} = query_params ->
        Search.search(search, query_params, index)

      _ ->
        Search.search(search, index)
    end
    |> transform_response()
  end

  defp transform_response(%{results: results} = response) do
    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(&Map.Helpers.atomize_keys/1)

    Map.put(response, :results, results)
  end

  defp do_rules_execution(user_defined_filters) do
    user_defined_filters
    |> Enum.filter(&Enum.at(Map.get(get_filter(&1), "executable", []), 0))
    |> Enum.empty?()
    |> Kernel.!()
  end

  defp get_filter(%{terms: field}), do: field
  defp get_filter(_), do: %{}
end
