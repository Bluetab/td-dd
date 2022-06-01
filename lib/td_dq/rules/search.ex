defmodule TdDq.Rules.Search do
  @moduledoc """
  The Rules Search context
  """

  alias TdDq.Auth.Claims
  alias TdDq.Rules.Search.Query
  alias Truedat.Search
  alias Truedat.Search.Permissions

  require Logger

  def get_filter_values(claims, params, index \\ :rules)

  def get_filter_values(%Claims{} = claims, params, index) do
    query = build_query(claims, params, index)
    aggs = aggregations(index)
    search = %{query: query, aggs: aggs, size: 0}
    Search.get_filters(search, index)
  end

  def search_rules(params, %Claims{} = claims, page \\ 0, size \\ 50) do
    query = build_query(claims, params, :rules)
    sort = Map.get(params, "sort", ["_score", "implementation_key.raw"])

    %{from: page * size, size: size, query: query, sort: sort}
    |> do_search(:rules, params)
  end

  def search_implementations(params, %Claims{} = claims, page \\ 0, size \\ 50) do
    query = build_query(claims, params, :implementations)
    sort = Map.get(params, "sort", ["_score", "implementation_key.raw"])

    %{from: page * size, size: size, query: query, sort: sort}
    |> do_search(:implementations, params)
  end

  defp build_query(%Claims{role: "service"} = claims, params, :implementations = index) do
    aggs = aggregations(index)

    {executable, params} =
      Map.get_and_update(params, "filters", fn
        nil ->
          :pop

        filters ->
          filters
          |> maybe_put_status()
          |> Map.pop("executable")
      end)

    claims
    |> search_permissions(executable)
    |> Query.build_query(params, aggs)
  end

  defp build_query(%Claims{} = claims, params, :rules = index) do
    aggs = aggregations(index)

    claims
    |> search_permissions(:not_executable)
    |> Query.build_query(params, aggs)
  end

  defp build_query(%Claims{} = claims, params, :implementations = index) do
    aggs = aggregations(index)

    {executable, params} =
      Map.get_and_update(params, "filters", fn
        nil -> :pop
        filters -> Map.pop(filters, "executable")
      end)

    claims
    |> search_permissions(executable)
    |> Query.build_query(params, aggs)
  end

  defp search_permissions(%Claims{} = claims, executable) do
    executable
    |> search_permissions()
    |> Permissions.get_search_permissions(claims)
  end

  defp search_permissions([_true] = _executable) do
    [
      "view_quality_rule",
      "manage_confidential_business_concepts",
      "execute_quality_rule_implementations"
    ]
  end

  defp search_permissions(_not_executable) do
    ["view_quality_rule", "manage_confidential_business_concepts"]
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

  defp aggregations(:rules) do
    TdDq.Rules.Search.Aggregations.aggregations()
  end

  defp aggregations(:implementations) do
    TdDq.Implementations.Search.Aggregations.aggregations()
  end

  defp maybe_put_status(%{"status" => _} = filters), do: filters

  defp maybe_put_status(filters), do: Map.put(filters, "status", ["published"])
end
