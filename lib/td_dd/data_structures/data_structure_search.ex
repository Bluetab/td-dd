defmodule TdDd.DataStructure.Search do
  @moduledoc """
    Helper module to construct business concept search queries.
  """
  alias TdDd.Search.Aggregations
  alias TdDd.Utils.CollectionUtils
  # alias TdDd.DataStructures.DataStructure
  # alias TdDd.Permissions

  @search_service Application.get_env(:td_dd, :elasticsearch)[:search_service]
  # @map_field_to_condition %{
  #   "q_rule_terms" => %{gt: 0},
  #   "linked_terms" => %{gt: 0},
  #   "not_linked_terms" =>  %{gte: 0, lt: 1},
  #   "not_q_rule_terms" =>  %{gte: 0, lt: 1}
  # }
  #
  # def get_filter_values(%User{is_admin: true}) do
  #   query = %{} |> create_query
  #   search = %{query: query, aggs: Aggregations.aggregation_terms()}
  #   @search_service.get_filters(search)
  # end
  #
  # def get_filter_values(%User{} = user) do
  #   permissions = user |> Permissions.get_domain_permissions()
  #   get_filter_values(permissions)
  # end
  #
  # def get_filter_values([]), do: %{}
  #
  # def get_filter_values(permissions) do
  #   filter = permissions |> create_filter_clause
  #   query = %{} |> create_query(filter)
  #   search = %{query: query, aggs: Aggregations.aggregation_terms()}
  #   @search_service.get_filters(search)
  # end

  def search_data_structures(params, page \\ 0, size \\ 50)

  # Admin user search, no filters applied
  def search_data_structures(params, page, size) do
    filter_clause = create_filters(params)

    query =
      case filter_clause do
        [] -> create_query(params)
        _ -> create_query(params, filter_clause)
      end
     search = %{
      from: page * size,
      size: size,
      query: query
      # aggs: Aggregations.aggregation_terms()
    }

    @search_service.search("data_structure", search)
    |> Enum.map(&Map.get(&1, "_source"))
    |> Enum.map(fn(ds) ->
        CollectionUtils.atomize_keys(Map.put(ds, "last_change_by", CollectionUtils.atomize_keys(Map.get(ds, "last_change_by"))))
      end)
    |> Enum.map(fn(ds) ->
        CollectionUtils.atomize_keys(Map.put(ds, "data_fields", Enum.map(ds.data_fields, fn(df) ->
          CollectionUtils.atomize_keys(Map.put(df, "last_change_by", CollectionUtils.atomize_keys(Map.get(df, "last_change_by"))))
        end)))
      end)

  end

  # Non-admin user search, filters applied
  # def search_data_structures(params, %User{} = user, page, size) do
  #   permissions = user |> Permissions.get_domain_permissions()
  #   filter_data_structures(params, permissions, page, size)
  # end

  # def list_data_structures(business_concept_id, %User{is_admin: true}) do
  #   query = %{business_concept_id: business_concept_id} |> create_query
  #   search = %{query: query}
  #   @search_service.search("business_concept", search)
  #   |> Enum.map(&Map.get(&1, "_source"))
  # end
  #
  # def list_data_structures(business_concept_id, %User{} = user) do
  #   permissions = user |> Permissions.get_domain_permissions()
  #   predefined_query = %{business_concept_id: business_concept_id} |> create_query
  #   filter = permissions |> create_filter_clause([predefined_query])
  #   query = create_query(nil, filter)
  #   search = %{query: query}
  #   @search_service.search("business_concept", search)
  #   |> Enum.map(&Map.get(&1, "_source"))
  # end

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

  # defp get_filter(%{terms: %{script: _}}, values, filter) do
  #    %{range: create_range(filter, values)}
  # end

  # defp create_range(_filter, []), do: []
  #
  # defp create_range(filter, values) do
  #   Map.new()
  #     |> Map.put_new(filter, buid_range_condition(values))
  # end
  #
  # defp buid_range_condition(values) do
  #   case length(values) do
  #     1 -> get_param_condition(values)
  #     2 -> %{gte: 0}
  #     _ -> %{}
  #   end
  # end
  #
  # defp get_param_condition([head|_tail]) do
  #   Map.fetch!(@map_field_to_condition, head)
  # end
  #
  # defp filter_data_structures(_params, [], _page, _size), do: []
  #
  # defp filter_data_structures(params, [_h | _t] = permissions, page, size) do
  #   user_defined_filters = create_filters(params)
  #
  #   filter = permissions |> create_filter_clause(user_defined_filters)
  #
  #   query = create_query(params, filter)
  #   search = %{from: page * size, size: size, query: query}
  #
  #   @search_service.search("business_concept", search)
  #   |> Enum.map(&Map.get(&1, "_source"))
  # end

  # defp create_query(%{business_concept_id: id}) do
  #   %{term: %{business_concept_id: id}}
  # end
  defp create_query(%{"query" => query}) do
    %{simple_query_string: %{query: query}}
    |> bool_query
  end

  defp create_query(_params) do
    %{match_all: %{}}
    |> bool_query
  end
  #
  # defp create_query(%{"query" => query}, filter) do
  #   %{simple_query_string: %{query: query}}
  #   |> bool_query(filter)
  # end
  #
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

  # defp create_filter_clause(permissions, user_defined_filters \\ []) do
  #   should_clause =
  #     permissions
  #     |> Enum.map(&entry_to_filter_clause(&1, user_defined_filters))
  #
  #   %{bool: %{should: should_clause}}
  # end
  #
  # defp entry_to_filter_clause(
  #        %{resource_id: resource_id, permissions: permissions},
  #        user_defined_filters
  #      ) do
  #
  #   domain_clause = %{term: %{domain_ids: resource_id}}
  #
  #   status_clause =
  #     permissions
  #     |> Enum.map(&Map.get(DataStructure.permissions_to_status(), &1))
  #     |> Enum.filter(&(!is_nil(&1)))
  #
  #   %{
  #     bool: %{filter: user_defined_filters ++ [domain_clause, %{terms: %{status: status_clause}}]}
  #   }
  # end
end
