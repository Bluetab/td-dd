defmodule TdDd.DataStructures.Search.Query do
  @moduledoc """
  Support for building data structure search queries.
  """

  alias TdCore.Search.Query

  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}
  @not_confidential %{term: %{"confidential" => false}}

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
    opts = query_data |> with_search_clauses() |> Keyword.new()
    Query.build_query(filters, params, opts)
  end

  defp with_search_clauses(%{fields: fields} = query_data) do
    multi_match_bool_prefix = %{
      multi_match: %{
        type: "bool_prefix",
        fields: fields,
        lenient: true,
        fuzziness: "AUTO"
      }
    }

    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, [multi_match_bool_prefix])
  end

  defp with_search_clauses(query_data) do
    Map.take(query_data, [:aggs])
  end
end
