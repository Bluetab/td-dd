defmodule TdDq.Implementations.Search do
  @moduledoc """
  The Rule Implementations Search context
  """

  alias TdCore.Search
  alias TdCore.Utils.CollectionUtils
  alias TdDq.Rules.Search, as: RulesSearch
  alias Truedat.Auth.Claims

  @index :implementations

  def search_by_rule_id(%{} = params, claims, rule_id, page \\ 0, size \\ 1_000) do
    params
    |> case do
      %{"filters" => filters} = params ->
        params
        |> Map.put("filters", Map.merge(%{"rule_id" => rule_id}, filters))

      %{} = params ->
        params
        |> Map.put("filters", %{
          "rule_id" => rule_id
        })
    end
    |> search(claims, page, size)
  end

  def search_executable(%{} = params, claims) do
    executable_filters =
      params
      |> Map.get("filters", %{})
      |> Map.put("executable", [true])

    params
    |> Map.put("filters", executable_filters)
    |> Map.delete("status")
    |> search(claims)
  end

  def search(%{} = params, claims, page \\ 0, size \\ 10_000) do
    %{results: implementations} =
      params
      |> filter_deleted()
      |> Map.drop(["page", "size"])
      |> RulesSearch.search_implementations(claims, page, size)

    implementations
  end

  def scroll_implementations(%{"scroll_id" => _, "scroll" => _} = params) do
    params
    |> Map.take(["scroll_id, scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  def scroll_implementations(params, %Claims{} = claims) do
    query = RulesSearch.build_query(claims, params, :implementations)

    sort = Map.get(params, "sort", ["_score", "implementation_key.sort"])

    %{limit: limit, size: size, ttl: ttl} = scroll_opts!()

    %{query: query, sort: sort, size: size}
    |> do_search(%{"scroll" => ttl})
    |> do_scroll(ttl, limit, [])
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
      |> Enum.map(&CollectionUtils.atomize_keys(&1, true))

    %{response | results: results}
  end

  defp scroll_opts! do
    opts = Application.fetch_env!(:td_dd, TdDd.DataStructures.Search)

    %{
      limit: Keyword.fetch!(opts, :max_bulk_results),
      size: Keyword.fetch!(opts, :es_scroll_size),
      ttl: Keyword.fetch!(opts, :es_scroll_ttl)
    }
  end

  defp do_scroll(%{results: []} = response, _ttl, _limit, acc), do: %{response | results: acc}

  defp do_scroll(%{results: results} = response, _ttl, limit, acc)
       when length(results) + length(acc) >= limit,
       do: %{response | results: acc ++ results}

  defp do_scroll(%{results: results, scroll_id: scroll_id} = _response, ttl, limit, acc) do
    %{"scroll_id" => scroll_id, "scroll" => ttl}
    |> Search.scroll()
    |> transform_response()
    |> do_scroll(ttl, limit, acc ++ results)
  end

  defp filter_deleted(%{"status" => "deleted"} = params) do
    params
    |> Map.delete("status")
    |> Map.put("with", "deleted_at")
  end

  defp filter_deleted(%{} = params) do
    params
    |> Map.delete("status")
    |> Map.put("without", "deleted_at")
  end
end
