defmodule TdDq.Rules.Search do
  @moduledoc """
  The Rules Search context
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.Search.Query
  alias Truedat.Auth.Claims

  require Logger

  @accepted_wildcards ["\"", ")"]

  def get_filter_values(claims, params, index \\ :rules)

  def get_filter_values(%Claims{} = claims, params, index) do
    query_data = %{aggs: aggs} = index |> fetch_query_data() |> with_search_clauses(params)
    query = build_query(claims, params, index, query_data)
    search = %{query: query, aggs: aggs, size: 0}
    Search.get_filters(search, index)
  end

  def search_rules(params, %Claims{} = claims, page \\ 0, size \\ 50) do
    query_data = :rules |> fetch_query_data() |> with_search_clauses(params)
    query = build_query(claims, params, :rules, query_data)
    sort = Map.get(params, "sort", ["_score", "name.raw"])

    %{from: page * size, size: size, query: query, sort: sort}
    |> do_search(:rules, params)
  end

  def search_implementations(params, %Claims{} = claims, page \\ 0, size \\ 50) do
    query_data = :implementations |> fetch_query_data() |> with_search_clauses(params)
    query = build_query(claims, params, :implementations, query_data)
    sort = Map.get(params, "sort", ["_score", "implementation_key.sort"])

    %{from: page * size, size: size, query: query, sort: sort}
    |> do_search(:implementations, params)
  end

  def build_query(%Claims{} = claims, params, index) do
    query_data = index |> fetch_query_data() |> with_search_clauses(params)
    build_query(claims, params, index, query_data)
  end

  def build_query(%Claims{} = claims, %{"must" => _} = params, index, query_data) do
    build_query(%Claims{} = claims, params, index, query_data, filter_type: :must)
  end

  def build_query(%Claims{} = claims, params, index, query_data) do
    build_query(%Claims{} = claims, params, index, query_data, filter_type: :filters)
  end

  def build_query(%Claims{} = claims, params, :rules, query_data, _opts) do
    claims
    |> search_permissions(:not_executable)
    |> Query.build_query(params, query_data)
  end

  def build_query(%Claims{} = claims, params, :implementations, query_data, opts) do
    filter_or_must = Atom.to_string(opts[:filter_type])

    {executable, params} =
      params
      |> put_default_filters(claims)
      |> Map.get_and_update(filter_or_must, fn
        nil ->
          :pop

        filters ->
          Map.pop(filters, "executable")
      end)

    claims
    |> search_permissions(executable)
    |> Query.build_query(params, query_data)
  end

  defp search_permissions(%Claims{} = claims, executable) do
    executable
    |> search_permissions()
    |> Permissions.get_search_permissions(claims)
  end

  defp search_permissions([_true] = _executable) do
    [
      "view_quality_rule",
      "manage_quality_rule_implementations",
      "manage_raw_quality_rule_implementations",
      "manage_confidential_business_concepts",
      "execute_quality_rule_implementations"
    ]
  end

  defp search_permissions(_not_executable) do
    [
      "view_quality_rule",
      "manage_quality_rule_implementations",
      "manage_raw_quality_rule_implementations",
      "manage_confidential_business_concepts"
    ]
  end

  def scroll_implementations(%{"scroll_id" => _, "scroll" => _} = params) do
    params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  defp do_search(search, index, %{"scroll" => scroll} = _params) do
    search
    |> Search.search(index, params: %{"scroll" => scroll})
    |> transform_response()
  end

  defp do_search(search, index, _params) do
    search
    |> Search.search(index)
    |> transform_response()
  end

  defp transform_response({:ok, response}), do: transform_response(response)
  defp transform_response({:error, _} = response), do: response

  defp transform_response(%{results: results} = response) do
    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(&Map.Helpers.atomize_keys/1)

    Map.put(response, :results, results)
  end

  defp put_default_filters(%{"must" => _} = params, %{role: "service"}) do
    defaults = %{"status" => ["published"]}
    Map.update(params, "must", defaults, &Map.merge(defaults, &1))
  end

  defp put_default_filters(%{} = params, %{role: "service"}) do
    defaults = %{"status" => ["published"]}
    Map.update(params, "filters", defaults, &Map.merge(defaults, &1))
  end

  defp put_default_filters(%{} = params, _claims), do: params

  defp fetch_query_data(:rules) do
    ElasticDocumentProtocol.query_data(%Rule{})
  end

  defp fetch_query_data(:implementations) do
    ElasticDocumentProtocol.query_data(%Implementation{})
  end

  defp with_search_clauses(query_data, params) do
    query_data
    |> Map.take([:aggs])
    |> Map.put(:clauses, [clause_for_query(query_data, params)])
  end

  defp clause_for_query(query_data, %{"query" => query}) when is_binary(query) do
    if String.last(query) in @accepted_wildcards do
      simple_query_string_clause(query_data)
    else
      multi_match_boolean_prefix(query_data)
    end
  end

  defp clause_for_query(query_data, _params) do
    multi_match_boolean_prefix(query_data)
  end

  defp multi_match_boolean_prefix(%{fields: fields}) do
    %{multi_match: %{type: "bool_prefix", fields: fields, lenient: true, fuzziness: "AUTO"}}
  end

  defp simple_query_string_clause(%{simple_search_fields: fields}) do
    %{simple_query_string: %{fields: fields}}
  end
end
