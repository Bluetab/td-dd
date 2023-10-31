defmodule TdDd.GrantRequests.Search do
  @moduledoc """
  The Grant Rquest Search context
  """

  alias TdDd.GrantRequests.Search.Aggregations
  alias TdDd.GrantRequests.Search.Query
  alias Truedat.Auth.Claims
  alias Truedat.Search
  alias Truedat.Search.Permissions

  require Logger

  @index :grant_requests

  def get_filter_values(%Claims{} = claims, params) do
    aggs = Aggregations.aggregations()

    query =
      claims
      |> search_permissions()
      |> Query.build_query(params, aggs)

    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end

  def search(params, claims, page \\ 0, size \\ 1000)

  def search(params, claims, _page, size) do
    aggs = Aggregations.aggregations()
    sort = Map.get(params, "sort", ["_score", "inserted_at"])

    query =
      claims
      |> search_permissions()
      |> Query.build_query(params, aggs)

    %{
      size: size,
      query: query,
      sort: sort
    }
    |> Search.search(@index)
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
    Permissions.get_search_permissions(["approve_grant_request"], claims)
  end
end
