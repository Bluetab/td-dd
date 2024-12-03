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

  def get_filter_values(%Claims{} = claims, params) do
    aggs = ElasticDocumentProtocol.aggregations(%GrantRequest{})

    query =
      claims
      |> search_permissions()
      |> Query.build_query(params, aggs)

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
    aggs = ElasticDocumentProtocol.aggregations(%GrantRequest{})
    sort = Map.get(params, "sort", ["_score", "inserted_at"])

    query =
      claims
      |> search_permissions()
      |> Query.build_query(params, aggs)

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
end
