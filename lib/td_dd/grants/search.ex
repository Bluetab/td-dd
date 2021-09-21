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
    filter_clause = Query.create_filters(params, @index)
    query = Query.create_query(%{}, filter_clause)
    search = %{query: query, aggs: Query.get_aggregation_terms(@index)}
    Search.get_filters(search, @index)
  end

  def get_filter_values(%Claims{} = claims, permission, params) do
    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, permission))

    get_filter_values(permissions, params)
  end

  def get_filter_values([], _params), do: %{}

  def get_filter_values(user_or_permissions, params) do
    user_defined_filters = Query.create_filters(params, @index)

    filter =
      case user_or_permissions do
        [_h | _t] = permissions -> Query.create_filter_clause(permissions, user_defined_filters)
        user_id -> Query.create_filter_clause_by(user_id, user_defined_filters)
      end

    query = Query.create_query(%{}, filter)
    search = %{query: query, aggs: Query.get_aggregation_terms(@index)}
    Search.get_filters(search, @index)
  end

  def scroll_grants(%{"scroll_id" => _, "scroll" => _} = scroll_params) do
    scroll_params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll(@index)
    |> transform_response()
  end

  def search(params, claims, page \\ 0, size \\ 50, index \\ :grants)

  def search(params, %Claims{role: role}, page, size, index) when role in ["admin", "service"] do
    filter_clause = Query.create_filters(params, index)
    query = Query.create_query(params, filter_clause)
    sort = Map.get(params, "sort", default_sort(index))

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> aggs(params, index)
    |> do_search(params, index)
  end

  def search(params, %Claims{} = claims, page, size, index) do
    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> get_permissions()

    filter(params, permissions, page, size, index)
  end

  def search_by_user(params, user_name, page \\ 0, size \\ 50, index \\ :grants)

  def search_by_user(params, user_name, page, size, index) do
    filter(params, user_name, page, size, index)
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

  defp filter(params, user_or_permissions, page, size, index) do
    user_defined_filters = Query.create_filters(params, index)

    filter =
      case user_or_permissions do
        [_h | _t] = permissions -> Query.create_filter_clause(permissions, user_defined_filters)
        user_id -> Query.create_filter_clause_by(user_id, user_defined_filters)
      end

    query = Query.create_query(params, filter)
    sort = Map.get(params, "sort", default_sort(index))

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> aggs(params, index)
    |> do_search(params, index)
  end

  # Don't request aggregations if we're scrolling
  defp aggs(%{} = search, %{"scroll" => _}, _index), do: search

  defp aggs(%{} = search, %{} = _params, index) do
    Map.put(search, :aggs, Query.get_aggregation_terms(index))
  end

  defp do_search(search, params, index) do
    params
    |> Map.take(["scroll"])
    |> case do
      %{"scroll" => _scroll} = query_params -> Search.search(search, query_params, index)
      _ -> Search.search(search, index)
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
end
