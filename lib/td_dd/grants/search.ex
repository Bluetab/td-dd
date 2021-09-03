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

  # def get_filter_values(permissions, params) do
  #   user_defined_filters = Query.create_filters(params, :grants)
  #   filter = permissions |> create_filter_clause(user_defined_filters)
  #   query = create_query(%{}, filter)
  #   search = %{query: query, aggs: Query.get_aggregation_terms(:grants)}
  #   Search.get_filters(search, :grants)
  # end


  def search(params, claims, page \\ 0, size \\ 50, index \\ :grants)

  def search(params, %Claims{role: role}, page, size, index) when role in ["admin", "service"] do
    IO.puts("SEARCH TdDd.Grants.Search")
    #IO.inspect(params, label: "params")
    #IO.inspect(index, label: "index")
    filter_clause = Query.create_filters(params, index)# |> IO.inspect(label: "create_filter")
    query = Query.create_query(params, filter_clause)# |> IO.inspect(label: "create_query")
    sort = Map.get(params, "sort", default_sort(index))# |> IO.inspect(label: "DEFAULT_SORT")

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort,
      aggs: Query.get_aggregation_terms(index)
    } |> IO.inspect(label: "QUERY")
    #|> IO.inspect(label: "search_before")
    |> do_search(index)
  end

  def search(params, %Claims{} = claims, page, size, index) do
    # user_defined_filters = Query.create_filters(params, index)

    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> get_permissions()

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

  def default_sort(:grants), do: ["_id"]

  # defp default_sort(:implementations), do: ["implementation_key.raw"]

  # defp get_permissions(domain_permissions, user_defined_filters, index) do
  #   case index do
  #     :rules -> get_permissions(domain_permissions)
  #     :implementations -> get_permissions(domain_permissions, user_defined_filters)
  #   end
  # end

  # defp get_permissions(domain_permissions, user_defined_filters) do
  #   Enum.filter(domain_permissions, fn permissions_obj ->
  #     case do_rules_execution(user_defined_filters) do
  #       true ->
  #         check_execute_and_view_permission(permissions_obj)

  #       false ->
  #         Enum.any?(permissions_obj.permissions, &check_view_or_manage_permission(&1))
  #     end
  #   end)
  # end

  defp get_permissions(domain_permissions) do
    Enum.filter(domain_permissions, fn %{permissions: permissions} ->
      Enum.any?(permissions, &check_view_or_manage_permission(&1))
    end)
  end

  # defp check_execute_and_view_permission(permissions_obj) do
  #   Enum.any?(permissions_obj.permissions, &check_view_or_manage_permission(&1))
  # end

  defp check_view_or_manage_permission(permission_names) do
    permission_names == :view_grants ||
      permission_names == :manage_grants
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
    #|> IO.inspect(label: "get_aggregation_terms")
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

  # defp do_rules_execution(user_defined_filters) do
  #   user_defined_filters
  #   |> Enum.filter(&Enum.at(Map.get(get_filter(&1), "executable", []), 0))
  #   |> Enum.empty?()
  #   |> Kernel.!()
  # end

  # defp get_filter(%{terms: field}), do: field
  # defp get_filter(_), do: %{}
end
