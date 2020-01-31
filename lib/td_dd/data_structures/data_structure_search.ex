defmodule TdDd.DataStructure.Search do
  @moduledoc """
  Helper module to construct business concept search queries.
  """
  alias TdDd.Accounts.User
  alias TdDd.Permissions
  alias TdDd.Search
  alias TdDd.Search.Aggregations
  alias TdDd.Utils.CollectionUtils

  require Logger

  def get_filter_values(user, permission, params)

  def get_filter_values(%User{is_admin: true}, _permission, params) do
    filter_clause = create_filters(params)
    query = create_query(%{}, filter_clause)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def get_filter_values(%User{} = user, permission, params) do
    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, permission))

    get_filter_values(permissions, params)
  end

  def get_filter_values([], _params), do: %{}

  def get_filter_values(permissions, params) do
    user_defined_filters = create_filters(params)
    filter = permissions |> create_filter_clause(user_defined_filters)
    query = create_query(%{}, filter)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def get_aggregations_values(%User{is_admin: true}, _permission, params, agg_terms) do
    filter_clause = create_filters(params)
    query = create_query(%{}, filter_clause)
    search = %{size: 0, query: query, aggs: agg_terms}
    search
    |> Search.search()
    |> get_aggregations_results(agg_terms)
  end

  def get_aggregations_values(%User{} = user, permission, params, agg_terms) do
    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, permission))

    get_agg_terms_with_perms(permissions, params, agg_terms)
  end

  defp get_agg_terms_with_perms([], _params, _agg_terms), do: []

  defp get_agg_terms_with_perms(permissions, params, agg_terms) do
    user_defined_filters = create_filters(params)
    filter = permissions |> create_filter_clause(user_defined_filters)
    query = create_query(%{}, filter)
    search = %{size: 0, query: query, aggs: agg_terms}
    search
    |> Search.search()
    |> get_aggregations_results(agg_terms)
  end

  defp get_aggregations_results(results, agg_terms) do
    [agg_term] = Map.keys(agg_terms)
    results = results
    |> Map.get(:aggregations, %{})
    |> Map.get(agg_term, %{})
    |> Map.get("buckets")
    case results do
      nil -> []
      _ -> results
    end
  end

  def search_data_structures(params, user, permission, page \\ 0, size \\ 50)

  def search_data_structures(params, %User{is_admin: true}, _permission, page, size) do
    filters = create_filters(params)
    query = create_query(params, filters)

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

  # Non-admin search
  def search_data_structures(params, %User{} = user, permission, page, size) do
    permissions =
      user
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, permission))

    filter_data_structures(params, permissions, page, size)
  end

  defp filter_data_structures(_params, [], _page, _size),
    do: %{results: [], aggregations: %{}, total: 0}

  defp filter_data_structures(params, [_h | _t] = permissions, page, size) do
    user_defined_filters = create_filters(params)

    filter = permissions |> create_filter_clause(user_defined_filters)

    query = create_query(params, filter)

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

  defp create_filter_clause(permissions, user_defined_filters) do
    should_clause =
      permissions
      |> Enum.map(&entry_to_filter_clause(&1, user_defined_filters))

    %{bool: %{should: should_clause}}
  end

  defp entry_to_filter_clause(
         %{resource_id: resource_id, permissions: permissions},
         user_defined_filters
       ) do
    domain_clause = %{term: %{domain_ids: resource_id}}

    confidential_clause =
      case Enum.member?(permissions, :manage_confidential_structures) do
        true -> %{terms: %{confidential: [true, false]}}
        false -> %{terms: %{confidential: [false]}}
      end

    %{
      bool: %{filter: user_defined_filters ++ [domain_clause, confidential_clause]}
    }
  end

  def create_filters(%{without: without_fields} = params) do
    filters = create_filters(Map.delete(params, :without))

    without_fields
    |> Enum.map(&%{bool: %{must_not: %{exists: %{field: &1}}}})
    |> Enum.concat(filters)
  end

  def create_filters(%{"filters" => filters}) do
    filters
    |> Map.to_list()
    |> Enum.map(&to_terms_query/1)
    |> Enum.reject(&is_nil/1)
  end

  def create_filters(_), do: []

  defp to_terms_query({:system_id, system_id}) do
    get_filter(nil, system_id, :system_id)
  end

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

  defp create_query(%{"query" => query}, filter) do
    ~r/\s/
    |> Regex.split(query, trim: true)
    |> Enum.map(&multi_match(&1))
    |> bool_query(filter)
  end

  defp create_query(_params, filter) do
    [%{match_all: %{}}]
    |> bool_query(filter)
  end

  defp multi_match(query) do
    %{
      multi_match: %{
        query: query,
        type: "phrase_prefix",
        fields: ["name^2", "name.ngram", "system.name", "data_fields.name", "path"]
      }
    }
  end

  defp bool_query(query, []), do: bool_query(query, nil)

  defp bool_query([clause], filter) when is_nil(filter) do
    %{bool: %{must: clause}}
  end

  defp bool_query(clauses, filter) when is_nil(filter) do
    %{bool: %{should: clauses, minimum_should_match: Enum.count(clauses)}}
  end

  defp bool_query([clause], filter) do
    %{bool: %{must: clause, filter: filter}}
  end

  defp bool_query(clauses, filter) do
    %{bool: %{should: clauses, filter: filter, minimum_should_match: Enum.count(clauses)}}
  end

  defp do_search(search) do
    %{results: results, aggregations: aggregations, total: total} = Search.search(search)

    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(fn ds ->
        last_change_by =
          ds
          |> Map.get("last_change_by", %{})
          |> CollectionUtils.atomize_keys()

        Map.put(ds, "last_change_by", last_change_by)
      end)
      |> Enum.map(fn ds ->
        data_fields =
          ds
          |> Map.get("data_fields", [])
          |> Enum.map(&CollectionUtils.atomize_keys/1)

        Map.put(ds, "data_fields", data_fields)
      end)
      |> Enum.map(&CollectionUtils.atomize_keys/1)

    %{results: results, aggregations: aggregations, total: total}
  end
end
