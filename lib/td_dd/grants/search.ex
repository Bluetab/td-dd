defmodule TdDd.Grants.Search do
  @moduledoc """
  The Grants Search context
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdDd.Grants.GrantStructure
  alias TdDd.Grants.Search.Query
  alias Truedat.Auth.Claims

  require Logger

  @index :grants
  @default_sort ["_id"]

  def get_filter_values(claims, params, user_id) do
    params = put_filter(params, "user_id", user_id)
    get_filter_values(claims, params)
  end

  def get_filter_values(%Claims{user_id: user_id} = claims, %{} = params) do
    aggs = ElasticDocumentProtocol.aggregations(%GrantStructure{})

    query =
      claims
      |> search_permissions()
      |> Query.build_query(user_id, params, aggs)

    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end

  def scroll_grants(%{"scroll_id" => _, "scroll" => _} = scroll_params) do
    scroll_params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  def search(params, claims, page \\ 0, size \\ 50)

  def search(params, %Claims{user_id: user_id} = claims, page, size) do
    sort = Map.get(params, "sort", @default_sort)
    aggs = ElasticDocumentProtocol.aggregations(%GrantStructure{})

    query =
      claims
      |> search_permissions()
      |> Query.build_query(user_id, params, aggs)

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> do_search(params)
  end

  def search_by_user(params, %{user_id: user_id} = claims, page \\ 0, size \\ 50) do
    params
    |> put_filter("user_id", user_id)
    |> search(claims, page, size)
  end

  defp put_filter(%{"must" => _} = params, field, condition) do
    Map.update(params, "must", %{field => condition}, &Map.put_new(&1, field, condition))
  end

  defp put_filter(params, field, condition) do
    Map.update(params, "filters", %{field => condition}, &Map.put_new(&1, field, condition))
  end

  defp do_search(search, %{"scroll" => scroll} = _params) do
    search
    |> Search.search(@index, params: %{"scroll" => scroll})
    |> transform_response()
  end

  defp do_search(search, _params) do
    search
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
    Permissions.get_search_permissions(["manage_grants", "view_grants"], claims)
  end
end
