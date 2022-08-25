defmodule TdDd.DataStructures.Search do
  @moduledoc """
  The Data Structures Search context
  """

  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Search.Aggregations
  alias TdDd.DataStructures.Search.Query
  alias TdDd.Utils.CollectionUtils
  alias Truedat.Search
  alias Truedat.Search.Permissions

  require Logger

  @index :structures

  def get_filter_values(claims, permission, params)

  def get_filter_values(%Claims{} = claims, permission, %{} = params) do
    aggs = Aggregations.aggregations()
    query = build_query(claims, permission, params, aggs)
    search = %{query: query, aggs: aggs, size: 0}
    Search.get_filters(search, @index)
  end

  def get_aggregations(%Claims{} = claims, aggs) do
    query = build_query(claims, "view_data_structure", %{}, aggs)
    search = %{query: query, aggs: aggs, size: 0}
    Search.search(search, @index, format: :raw)
  end

  def scroll_data_structures(%{"scroll_id" => _, "scroll" => _} = params) do
    params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  def search_data_structures(params, claims, permission, page \\ 0, size \\ 50)

  def search_data_structures(params, %Claims{} = claims, permission, page, size) do
    aggs = Aggregations.aggregations()

    query = build_query(claims, permission, params, aggs)
    sort = Map.get(params, "sort", ["_score", "name.raw"])

    %{
      query: query,
      sort: sort
    }
    |> maybe_add_from_size(page, size)
    |> do_search(params)
  end

  defp maybe_add_from_size(query, _page, :infinity = _size) do
    Map.put(query, :size, :infinity)
  end

  defp maybe_add_from_size(query, page, size) do
    Map.merge(
      %{
        from: page * size,
        size: size
      },
      query
    )
  end

  defp build_query(%Claims{} = claims, permission, %{} = params, %{} = aggs) do
    claims
    |> search_permissions(permission)
    |> Query.build_query(params, aggs)
  end

  defp do_search(%{size: :infinity} = query, _params) do
    query
    |> Search.search(@index)
    |> transform_response()
  end

  defp do_search(query, %{"scroll" => scroll} = _params) do
    query
    |> Search.search(@index, params: %{"scroll" => scroll})
    |> transform_response()
  end

  defp do_search(query, _params) do
    query
    |> Search.search(@index)
    |> transform_response()
  end

  defp transform_response({:ok, response}), do: transform_response(response)
  defp transform_response({:error, _} = response), do: response

  defp transform_response(%{results: results} = response) do
    results =
      results
      |> Enum.map(&Map.get(&1, "_source"))
      |> Enum.map(fn ds ->
        last_change_by =
          ds
          |> Map.get("last_change_by", %{})
          |> CollectionUtils.atomize_keys()

        Map.put(ds, "last_change_by", last_change_by)
      end)
      |> Enum.map(fn ds ->
        data_fields =
          ds
          |> Map.get("data_fields", [])
          |> Enum.map(&CollectionUtils.atomize_keys/1)

        Map.put(ds, "data_fields", data_fields)
      end)
      |> Enum.map(&CollectionUtils.atomize_keys/1)

    %{response | results: results}
  end

  defp search_permissions(claims, permission) do
    [to_string(permission), "manage_confidential_structures"]
    |> Permissions.get_search_permissions(claims)
  end
end
