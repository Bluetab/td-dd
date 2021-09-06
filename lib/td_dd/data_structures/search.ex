defmodule TdDd.DataStructures.Search do
  @moduledoc """
  Helper module to construct business concept search queries.
  """
  alias TdDd.Auth.Claims
  alias TdDd.Permissions
  alias TdDd.Search
  alias TdDd.Search.Aggregations
  alias TdDd.Utils.CollectionUtils

  require Logger

  def get_filter_values(claims, permission, params)

  def get_filter_values(%Claims{role: role}, _permission, params)
      when role in ["admin", "service"] do
    filter_clause = create_filters(params)
    query = create_query(%{}, filter_clause)
    search = %{query: query, aggs: Aggregations.aggregation_terms()}
    Search.get_filters(search)
  end

  def get_filter_values(%Claims{} = claims, permission, params) do
    permissions =
      claims
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

  @spec get_aggregations_values(TdDd.Auth.Claims.t(), any, any, any) :: list
  def get_aggregations_values(%Claims{role: role}, _permission, params, agg_terms)
      when role in ["admin", "service"] do
    filter_clause = create_filters(params)
    query = create_query(%{}, filter_clause)
    search = %{size: 0, query: query, aggs: agg_terms}

    search
    |> Search.search()
    |> get_aggregations_results(agg_terms)
  end

  def get_aggregations_values(%Claims{} = claims, permission, params, agg_terms) do
    permissions =
      claims
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
    agg_names = get_aggregations_names(%{"aggs" => agg_terms})
    results = Map.get(results, :aggregations)
    get_agg_results(agg_names, results)
  end

  defp get_agg_results([agg_name | agg_names], results) do
    results =
      results
      |> Map.get(agg_name, %{})
      |> Map.get("buckets", [])

    Enum.map(results, fn bucket ->
      agg_name_values = %{
        "type" => agg_name,
        "doc_count" => bucket["doc_count"],
        "key" => bucket["key"]
      }

      case agg_names do
        [] -> agg_name_values
        _ -> Map.put(agg_name_values, "aggs", get_agg_results(agg_names, bucket))
      end
    end)
  end

  # Extracts aggregations name from aggs format like:
  #   %{
  #     "systems" => %{
  #     :terms => %{field: "system.name.raw"},
  #     "aggs" => %{
  #       "types" => %{
  #         :terms => %{field: "type.raw"},
  #         "aggs" => %{"groups" => %{terms: %{field: "group.raw"}}}
  #       }
  #     }
  #   }
  defp get_aggregations_names(agg_terms) do
    case Map.get(agg_terms, "aggs") do
      nil ->
        []

      aggs ->
        [agg_key] = Map.keys(aggs)
        key_aggs = Map.get(aggs, agg_key)
        [agg_key] ++ get_aggregations_names(key_aggs)
    end
  end

  def scroll_data_structures(%{"scroll_id" => _, "scroll" => _} = scroll_params) do
    scroll_params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  def search_data_structures(params, claims, permission, page \\ 0, size \\ 50)

  def search_data_structures(params, %Claims{role: role}, _permission, page, size)
      when role in ["admin", "service"] do
    filters = create_filters(params)
    query = create_query(params, filters)

    sort = Map.get(params, "sort", ["name.raw"])

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> aggs(params)
    |> do_search(params)
  end

  # Non-admin search
  def search_data_structures(params, %Claims{} = claims, permission, page, size) do
    permissions =
      claims
      |> Permissions.get_domain_permissions()
      |> Enum.filter(&Enum.member?(&1.permissions, permission))

    filter_data_structures(params, permissions, page, size)
  end

  # Don't request aggregations if we're scrolling
  defp aggs(%{} = search_body, %{"scroll" => _}), do: search_body

  defp aggs(%{} = search_body, %{} = _params) do
    Map.put(search_body, :aggs, Aggregations.aggregation_terms())
  end

  defp filter_data_structures(_params, [], _page, _size) do
    %{results: [], aggregations: %{}, total: 0}
  end

  defp filter_data_structures(params, [_h | _t] = permissions, page, size) do
    user_defined_filters = create_filters(params)
    filter = create_filter_clause(permissions, user_defined_filters)
    query = create_query(params, filter)
    sort = Map.get(params, "sort", ["name.raw"])

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> aggs(params)
    |> do_search(params)
  end

  defp create_filter_clause(permissions, user_defined_filters) do
    should_clause = Enum.map(permissions, &entry_to_filter_clause(&1, user_defined_filters))
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
    filters =
      params
      |> Map.delete(:without)
      |> create_filters()

    without_fields
    |> Enum.map(&%{bool: %{must_not: %{exists: %{field: &1}}}})
    |> Enum.concat(filters)
  end

  def create_filters(%{"filters" => filters}) do
    filters
    |> Map.to_list()
    |> Enum.map(&to_filter_query/1)
    |> Enum.reject(&is_nil/1)
  end

  def create_filters(_), do: []

  defp to_filter_query({:system_id, system_id}) do
    get_filter(nil, system_id, :system_id)
  end

  defp to_filter_query({filter, value}) when filter in ["updated_at", "start_date", "end_date"] do
    %{range: %{String.to_atom(filter) => value}}
  end

  defp to_filter_query({filter, values}) do
    Aggregations.aggregation_terms()
    |> Map.get(filter)
    |> get_filter(values, filter)
  end

  defp get_filter(%{terms: %{field: field}}, values, _) do
    %{terms: %{field => values}}
  end

  defp get_filter(%{aggs: %{distinct_search: distinct_search}, nested: %{path: path}}, values, _) do
    %{nested: %{path: path, query: build_nested_query(distinct_search, values)}}
  end

  defp get_filter(nil, values, filter) when is_list(values) do
    %{terms: %{filter => values}}
  end

  defp get_filter(nil, value, filter) when not is_list(value) do
    %{term: %{filter => value}}
  end

  defp get_filter(_, ["linked"], "linked_concepts_count") do
    %{range: %{"linked_concepts_count" => %{gt: 0}}}
  end

  defp get_filter(_, ["unlinked"], "linked_concepts_count") do
    %{term: %{"linked_concepts_count" => 0}}
  end

  defp get_filter(_, _, _), do: nil

  defp build_nested_query(%{terms: %{field: field}}, values) do
    %{terms: %{field => values}}
    |> bool_query()
  end

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
        lenient: true,
        type: "phrase_prefix",
        fields: [
          "name^2",
          "name.ngram",
          "system.name",
          "path.text",
          "description",
          "latest_note.*"
        ]
      }
    }
  end

  defp bool_query(query, []), do: bool_query(query, nil)

  defp bool_query([clause], filter) when is_nil(filter) do
    %{bool: %{must: clause}}
  end

  defp bool_query(clauses, filter) when is_nil(filter) do
    # https://www.elastic.co/guide/en/elasticsearch/reference/6.2/query-dsl-minimum-should-match.html
    # If there are 2 clauses they are both required. For 3 or more clauses only
    # 75% are required.
    %{bool: %{should: clauses, minimum_should_match: "2<-75%"}}
  end

  defp bool_query([clause], filter) do
    %{bool: %{must: clause, filter: filter}}
  end

  defp bool_query(clauses, filter) do
    %{bool: %{should: clauses, filter: filter, minimum_should_match: Enum.count(clauses)}}
  end

  defp bool_query(query) do
    %{bool: %{must: query}}
  end

  defp do_search(search, params) do
    IO.puts("TdDd.DataStructures.Search")
    params
    |> Map.take(["scroll"])
    |> case do
      %{"scroll" => _scroll} = query_params -> Search.search(search, query_params)
      _ -> Search.search(search)
    end
    |> transform_response()
  end

  defp transform_response(%{results: results} = response) do
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

    Map.put(response, :results, results)
  end
end
