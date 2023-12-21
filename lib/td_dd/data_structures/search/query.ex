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

  def build_query(permissions, params, aggs) do
    permissions
    |> build_filters()
    |> do_build_query(params, aggs)
  end

  defp do_build_query(filters, params, aggs) do
    {query, params} = Map.pop(params, "query", "")
    words = Regex.split(~r/\s/, query, trim: true)

    filters
    |> Query.build_query(params, aggs)
    |> do_build_query(words)
  end

  defp do_build_query(query, []), do: query

  defp do_build_query(%{bool: %{must: must} = bool} = query, words) do
    must_query = build_bool_query(words)

    %{query | bool: Map.put(bool, :must, List.flatten([must_query, must]))}
  end

  defp do_build_query(%{bool: bool} = query, words) do
    must_query = build_bool_query(words)

    %{query | bool: Map.put(bool, :must, must_query)}
  end

  defp build_bool_query(words) do
    words
    |> Enum.map(&multi_match/1)
    |> maybe_bool_query()
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
          "original_name^1.5",
          "original_name.ngram",
          "system.name",
          "path.text",
          "description",
          "note.*"
        ]
      }
    }
  end

  defp maybe_bool_query([clause]), do: clause

  defp maybe_bool_query(should) do
    # https://www.elastic.co/guide/en/elasticsearch/reference/6.2/query-dsl-minimum-should-match.html
    # If there are 2 clauses they are both required. For 3 or more clauses only
    # 75% are required.
    %{bool: %{should: should, minimum_should_match: "2<-75%"}}
  end

  def maybe_add_search_after(query, [_ | _] = results) do
    maybe_add_search_after(query, List.last(results))
  end

  def maybe_add_search_after(query, %{"sort" => last_element}) do
    Map.put(query, :search_after, last_element)
  end

  def maybe_add_search_after(query, _), do: query
end
