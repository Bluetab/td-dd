defmodule TdDd.DataStructures.Search do
  @moduledoc """
  The Data Structures Search context
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Permissions
  alias TdCore.Utils.CollectionUtils
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Search.Query
  alias Truedat.Auth.Claims

  require Logger

  @index :structures

  def get_filter_values(claims, permission, params)

  def get_filter_values(%Claims{} = claims, permission, %{} = params) do
    aggs = ElasticDocumentProtocol.aggregations(%DataStructureVersion{})
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

  def scroll_data_structures(params, %Claims{} = claims, permission) do
    aggs = ElasticDocumentProtocol.aggregations(%DataStructureVersion{})
    query = build_query(claims, permission, params, aggs)
    sort = Map.get(params, "sort", ["_score", "name.raw", "id"])

    %{limit: limit, size: size, ttl: ttl} = scroll_opts!()

    %{query: query, sort: sort, size: size}
    |> do_search(%{"scroll" => ttl})
    |> do_scroll(ttl, limit, [])
  end

  defp scroll_opts! do
    opts = Application.fetch_env!(:td_dd, __MODULE__)

    %{
      limit: Keyword.fetch!(opts, :max_bulk_results),
      size: Keyword.fetch!(opts, :es_scroll_size),
      ttl: Keyword.fetch!(opts, :es_scroll_ttl)
    }
  end

  defp do_scroll(%{results: []} = response, _ttl, _limit, acc) do
    %{response | results: acc}
  end

  defp do_scroll(%{results: results} = response, _ttl, limit, acc)
       when length(results) + length(acc) >= limit do
    %{response | results: acc ++ results}
  end

  defp do_scroll(%{results: results, scroll_id: scroll_id} = _response, ttl, limit, acc) do
    %{"scroll_id" => scroll_id, "scroll" => ttl}
    |> Search.scroll()
    |> transform_response()
    |> do_scroll(ttl, limit, acc ++ results)
  end

  def bucket_structures(claims, permission, params) do
    initial_without = ["deleted_at"]

    {filters, without} =
      params
      |> Enum.find(fn {_key, val} -> val == ElasticDocument.missing_term_name() end)
      |> Kernel.then(fn
        {key, _val} -> {Map.drop(params, [key]), ["#{key}" | initial_without]}
        nil -> {params, initial_without}
      end)

    %{}
    |> Map.put("filters", filters)
    |> Map.put("without", without)
    |> search_data_structures(claims, permission, 0, 1_000)
  end

  def search_data_structures(params, claims, permission, page \\ 0, size \\ 50)

  def search_data_structures(params, %Claims{} = claims, permission, page, size) do
    aggs = ElasticDocumentProtocol.aggregations(%DataStructureVersion{})

    query = build_query(claims, permission, params, aggs)
    sort = Map.get(params, "sort", ["_score", "name.raw"])

    do_search(%{query: query, sort: sort, from: page * size, size: size}, params)
  end

  defp build_query(%Claims{} = claims, permission, %{} = params, %{} = aggs) do
    claims
    |> search_permissions(permission)
    |> Query.build_query(params, aggs)
  end

  defp do_search(query, %{"scroll" => scroll} = _params) do
    query
    |> Search.search(@index, params: %{"scroll" => scroll})
    |> transform_response()
  end

  defp do_search(query, _params) do
    query
    |> Search.search(@index, params: %{"track_total_hits" => "true"})
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
