defmodule TdDd.DataStructures.Search.Query do
  @moduledoc """
  Support for building data structure search queries.
  """

  alias TdCore.Search.Query

  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}
  @not_confidential %{term: %{"confidential" => false}}
  @accepted_wildcards ["\"", ")"]

  def build_filters(%{
        "view_data_structure" => view_scope,
        "manage_confidential_structures" => confidential_scope
      }) do
    do_build_filters(view_scope, confidential_scope)
  end

  def build_filters(%{
        "link_data_structure" => view_scope,
        "manage_confidential_structures" => confidential_scope
      }) do
    do_build_filters(view_scope, confidential_scope)
  end

  def build_filters(%{
        "create_grant_request" => view_scope,
        "manage_confidential_structures" => confidential_scope
      }) do
    do_build_filters(view_scope, confidential_scope)
  end

  def build_filters(%{} = _permissions), do: @match_none

  def structure_filter(structure_ids) do
    Query.term_or_terms("data_structure_id", structure_ids)
  end

  defp do_build_filters(:none, _), do: @match_none
  defp do_build_filters(:all, :all), do: @match_all
  defp do_build_filters(:all, :none), do: @not_confidential

  defp do_build_filters(:all, domain_ids) do
    %{bool: %{should: [domain_filter(domain_ids), @not_confidential]}}
  end

  defp do_build_filters(domain_ids, :all), do: domain_filter(domain_ids)

  defp do_build_filters(domain_ids, :none) do
    [domain_filter(domain_ids), @not_confidential]
  end

  defp do_build_filters(domain_ids, confidential_domain_ids) do
    f1 = %{bool: %{filter: [domain_filter(domain_ids), @not_confidential]}}
    f2 = %{bool: %{filter: domain_filter(confidential_domain_ids)}}
    %{bool: %{should: [f1, f2]}}
  end

  defp domain_filter(domain_ids) do
    Query.term_or_terms("domain_ids", domain_ids)
  end

  def build_query(permissions, params, query_data) do
    permissions
    |> build_filters()
    |> do_build_query(params, query_data)
  end

  defp do_build_query(filters, params, query_data) do
    opts = query_data |> with_search_clauses(params) |> Keyword.new()
    Query.build_query(filters, params, opts)
  end

  defp with_search_clauses(
         %{fields: _fields, simple_search_fields: _simple_search_fields} = query_data,
         params
       ) do
    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, [clause_for_query(query_data, params)])
  end

  defp with_search_clauses(query_data, _params) do
    Map.take(query_data, [:aggs])
  end

  defp clause_for_query(query_data, %{
         "query" => query,
         "search_fields" => search_fields,
         "operator" => operator
       })
       when is_binary(query) do
    custom_query_data = %{
      query_data
      | fields: search_fields,
        simple_search_fields: search_fields
    }

    if String.last(query) in @accepted_wildcards do
      simple_query_string_clause(custom_query_data.simple_search_fields, %{
        default_operator: operator
      })
    else
      multi_match_boolean_prefix(custom_query_data.fields, %{operator: operator})
    end
  end

  defp clause_for_query(query_data, %{"query" => query, "search_fields" => search_fields})
       when is_binary(query) do
    custom_query_data = %{
      query_data
      | fields: search_fields,
        simple_search_fields: search_fields
    }

    if String.last(query) in @accepted_wildcards do
      simple_query_string_clause(custom_query_data.simple_search_fields, %{default_operator: "OR"})
    else
      multi_match_boolean_prefix(custom_query_data.fields, %{operator: "OR"})
    end
  end

  defp clause_for_query(query_data, %{"query" => query}) when is_binary(query) do
    if String.last(query) in @accepted_wildcards do
      simple_query_string_clause(query_data.simple_search_fields)
    else
      multi_match_boolean_prefix(query_data.fields, %{fuzziness: "AUTO"})
    end
  end

  defp clause_for_query(query_data, _params) do
    multi_match_boolean_prefix(query_data.fields, %{fuzziness: "AUTO"})
  end

  defp multi_match_boolean_prefix(fields, params) do
    base = %{
      type: "bool_prefix",
      fields: fields,
      lenient: true
    }

    Enum.reduce(params, base, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
    |> then(&%{multi_match: &1})
  end

  defp simple_query_string_clause(fields, params \\ %{}) do
    base = %{
      fields: fields,
      quote_field_suffix: ".exact"
    }

    Enum.reduce(params, base, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
    |> then(&%{simple_query_string: &1})
  end
end
