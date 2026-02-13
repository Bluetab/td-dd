defmodule TdDd.DataStructures.Search.Query do
  @moduledoc """
  Support for building data structure search queries.
  """

  alias TdCore.Search.Query

  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}
  @accepted_wildcards ["\"", ")"]

  def build_filters(_permissions, _opts \\ [])

  def build_filters(
        %{
          "view_data_structure" => view_scope,
          "manage_confidential_structures" => confidential_scope
        },
        opts
      ) do
    do_build_filters(view_scope, confidential_scope, opts)
  end

  def build_filters(
        %{
          "link_data_structure" => view_scope,
          "manage_confidential_structures" => confidential_scope
        },
        opts
      ) do
    do_build_filters(view_scope, confidential_scope, opts)
  end

  def build_filters(
        %{
          "create_grant_request" => view_scope,
          "manage_confidential_structures" => confidential_scope
        },
        opts
      ) do
    do_build_filters(view_scope, confidential_scope, opts)
  end

  def build_filters(%{} = _permissions, _opts), do: @match_none

  def structure_filter(structure_ids) do
    Query.term_or_terms("data_structure_id", structure_ids)
  end

  defp do_build_filters(:none, _, _), do: @match_none
  defp do_build_filters(:all, :all, _), do: @match_all

  defp do_build_filters(:all, :none, opts) do
    not_confidential_filter(opts)
  end

  defp do_build_filters(:all, domain_ids, opts) do
    %{
      bool: %{
        should: [
          domain_filter(domain_ids, opts),
          not_confidential_filter(opts)
        ]
      }
    }
  end

  defp do_build_filters(domain_ids, :all, opts), do: domain_filter(domain_ids, opts)

  defp do_build_filters(domain_ids, :none, opts) do
    [domain_filter(domain_ids, opts), not_confidential_filter(opts)]
  end

  defp do_build_filters(domain_ids, confidential_domain_ids, opts) do
    f1 = %{
      bool: %{
        filter: [
          domain_filter(domain_ids, opts),
          not_confidential_filter(opts)
        ]
      }
    }

    f2 = %{bool: %{filter: domain_filter(confidential_domain_ids, opts)}}
    %{bool: %{should: [f1, f2]}}
  end

  defp domain_filter(domain_ids, opts) do
    field_prefix = Keyword.get(opts, :field_prefix, "")
    Query.term_or_terms("#{field_prefix}domain_ids", domain_ids)
  end

  defp not_confidential_filter(opts) do
    field_prefix = Keyword.get(opts, :field_prefix, "")
    %{term: %{"#{field_prefix}confidential" => false}}
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
         %{query: %{simple: _fields, as_you_type: _as_you_type, exact: _exact}} = query_data,
         params
       ) do
    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, clause_for_query(query_data, params))
  end

  defp with_search_clauses(query_data, _params) do
    Map.take(query_data, [:aggs])
  end

  defp clause_for_query(query_data, %{"query" => query}) when is_binary(query) do
    if String.last(query) in @accepted_wildcards do
      strict_clause(query_data)
    else
      search_clause(query_data)
    end
  end

  defp clause_for_query(query_data, _params), do: search_clause(query_data)

  defp search_clause(%{query: %{simple: simple, as_you_type: as_you_type, exact: exact}}) do
    %{
      must: %{multi_match: %{type: "bool_prefix", fields: as_you_type, lenient: true}},
      should: [
        %{multi_match: %{type: "phrase_prefix", fields: simple, boost: 4.0, lenient: true}},
        %{simple_query_string: %{fields: exact, quote_field_suffix: ".exact", boost: 4.0}}
      ]
    }
  end

  defp strict_clause(%{query: %{simple: fields}}) do
    %{must: %{simple_query_string: %{fields: fields, quote_field_suffix: ".exact"}}}
  end
end
