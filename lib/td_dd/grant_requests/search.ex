defmodule TdDd.GrantRequests.Search do
  @moduledoc """
  The Grant Rquest Search context
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdDd.GrantRequests.Search.Query
  alias TdDd.Grants.GrantRequest
  alias Truedat.Auth.Claims

  require Logger

  @index :grant_requests
  @accepted_wildcards ["\"", ")"]

  def get_filter_values(%Claims{} = claims, params) do
    query_data = %{aggs: aggs} = fetch_query_data(params)

    query =
      claims
      |> search_permissions()
      |> Query.build_query(params, query_data)

    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end

  def apply_approve_filters(%{"must" => %{"must_not_approved_by" => approved_by} = must} = params) do
    must =
      must
      |> Map.delete("must_not_approved_by")
      |> Map.put("current_status", ["pending"])

    params
    |> Map.put("must", must)
    |> Map.put("must_not", %{"approved_by" => approved_by})
  end

  def apply_approve_filters(params), do: params

  def search(params, claims, page \\ 0, size \\ 1000)

  def search(%{"scroll_id" => _} = params, _claims, _page, _size) do
    params
    |> Map.take(["scroll", "scroll_id"])
    |> Search.scroll()
    |> transform_response()
  end

  def search(params, claims, page, size) do
    query_data = fetch_query_data(params)
    sort = Map.get(params, "sort", ["_score", "inserted_at"])

    query =
      claims
      |> search_permissions()
      |> Query.build_query(params, query_data)

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> do_search(params)
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

  defp search_permissions(%Claims{} = claims) do
    permissions = ["manage_grants", "approve_grant_request"]

    ["domain", "structure"]
    |> Enum.map(fn resource_type ->
      Permissions.get_search_permissions(permissions, claims, resource_type)
      |> Enum.map(fn {permission, ids} -> {permission, %{resource_type => ids}} end)
      |> Map.new()
    end)
    |> Enum.reduce(%{}, fn ids_by_resource, acc ->
      Map.merge(acc, ids_by_resource, fn _k, v1, v2 -> Map.merge(v1, v2) end)
    end)
  end

  defp do_search(query, %{"scroll" => scroll} = _params) do
    Search.search(query, @index, params: %{"scroll" => scroll})
  end

  defp do_search(query, _params) do
    Search.search(query, @index)
  end

  defp fetch_query_data(params) do
    %GrantRequest{}
    |> ElasticDocumentProtocol.query_data()
    |> with_search_clauses(params)
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
