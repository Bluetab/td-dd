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
  alias TdDd.DataStructures.ElasticDocument, as: DSElasticDocument
  alias TdDd.DataStructures.Search.Query
  alias Truedat.Auth.Claims

  require Logger

  @index :structures

  def get_filter_values(claims, permission, params)

  def get_filter_values(%Claims{} = claims, permission, %{} = params) do
    query_data = %{aggs: aggs} = ElasticDocumentProtocol.query_data(%DataStructureVersion{})
    query = build_query(claims, permission, params, query_data)
    search = %{query: query, aggs: aggs, size: 0, _source: %{excludes: ["embeddings"]}}
    Search.get_filters(search, @index)
  end

  def get_bucket_paths(%Claims{} = claims, permission, %{} = params) do
    query_data = %{aggs: aggs} = ElasticDocumentProtocol.query_data(%DataStructureVersion{})
    aggs = Map.merge(DSElasticDocument.id_path_agg(), aggs)

    query = build_query(claims, permission, params, %{query_data | aggs: aggs})
    search = %{query: query, aggs: aggs, size: 0, _source: %{excludes: ["embeddings"]}}
    {:ok, %{"id_path" => %{buckets: buckets}}} = Search.get_filters(search, @index)

    buckets
    |> Enum.reduce(
      %{branches: [], filtered_children: %{}},
      fn
        %{
          "key" => string_path,
          "filtered_children_ids" => %{"buckets" => filtered_children_ids_buckets}
        },
        %{branches: branches, filtered_children: filtered_children} ->
          path = to_array_path(string_path)

          filtered_children_ids =
            Enum.map(
              filtered_children_ids_buckets,
              &String.to_integer(&1["key"])
            )

          # Use 0 instead of nil as default for empty List.last (filtered_children of root element)
          %{
            branches: [path | branches],
            filtered_children:
              Map.put(filtered_children, List.last(path, 0), filtered_children_ids)
          }
      end
    )
    |> forest_with_filtered_children
  end

  def vector(%Claims{} = claims, permission, %{} = params) do
    bool_filters =
      claims
      |> permission_filter(permission)
      |> exlude_structures(params)

    knn =
      params
      |> Map.take(["field", "query_vector", "k", "num_candidates"])
      |> Map.put("filter", %{bool: bool_filters})

    %{knn: knn, _source: %{excludes: ["embeddings"]}, sort: ["_score"]}
    |> Search.search(@index)
    |> transform_response()
  end

  defp permission_filter(claims, permission) do
    filter =
      claims
      |> search_permissions(permission)
      |> Query.build_filters()

    %{"filter" => filter}
  end

  defp exlude_structures(filters, %{"structure_ids" => [_ | _] = structure_ids}) do
    data_structure_filters = Query.structure_filter(structure_ids)
    Map.merge(filters, %{"must_not" => [data_structure_filters]})
  end

  defp exlude_structures(filters, _params), do: filters

  defp to_array_path(""), do: []

  defp to_array_path(string_path) do
    string_path
    |> String.split("-")
    |> Enum.map(&String.to_integer/1)
  end

  defp forest_with_filtered_children(%{branches: branches, filtered_children: filtered_children}) do
    %{
      forest: to_forest(branches),
      filtered_children: filtered_children
    }
  end

  defp to_forest(branches) do
    Enum.reduce(
      branches,
      %{},
      fn path, tree ->
        merge(tree, path)
      end
    )
  end

  # https://elixirforum.com/t/transform-list-into-nested-map/1001/2
  defp merge(map, []), do: map

  defp merge(map, [node | remaining_keys]) do
    inner_map = merge(Map.get(map, node, %{}), remaining_keys)
    Map.put(map, node, inner_map)
  end

  def get_aggregations(%Claims{} = claims, aggs) do
    query = build_query(claims, "view_data_structure", %{}, %{aggs: aggs})
    search = %{query: query, aggs: aggs, size: 0, _source: %{excludes: ["embeddings"]}}
    Search.search(search, @index, format: :raw)
  end

  def scroll_data_structures(%{"scroll_id" => _} = params) do
    params
    |> Map.take(["scroll_id", "scroll"])
    |> Search.scroll()
    |> transform_response()
  end

  def scroll_data_structures(params, %Claims{} = claims, permission) do
    query_data = ElasticDocumentProtocol.query_data(%DataStructureVersion{})
    query = build_query(claims, permission, params, query_data)
    sort = Map.get(params, "sort", ["_score", "name.raw", "id"])

    %{limit: limit, size: size, ttl: ttl} = scroll_opts!()

    %{query: query, sort: sort, size: size, _source: %{excludes: ["embeddings"]}}
    |> do_search(%{"scroll" => ttl})
    |> do_scroll(ttl, limit, [])
  end

  defp scroll_opts! do
    opts = Application.fetch_env!(:td_dd, TdDd.DataStructures.Search)

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

  def bucket_structures(claims, permission, %{"filters" => filters} = params) do
    initial_without = ["deleted_at"]

    # Currently not using ElasticDocument.missing_term_name as possible
    # aggregation because it does not work at the moment with catalog views.
    # Maybe will scrap it, not sure yet...
    {filters, without} =
      filters
      |> Enum.find(fn {_key, val} -> val == ElasticDocument.missing_term_name() end)
      |> Kernel.then(fn
        {key, _val} -> {Map.drop(filters, [key]), ["#{key}" | initial_without]}
        nil -> {filters, initial_without}
      end)

    %{}
    |> maybe_put_query(params)
    |> Map.put("filters", filters)
    |> Map.put("without", without)
    |> search_data_structures(claims, permission, 0, 1_000)
  end

  defp maybe_put_query(transformed_params, %{"query" => query}) when is_binary(query) do
    case String.trim(query) do
      "" -> transformed_params
      _ -> Map.put(transformed_params, "query", query)
    end
  end

  defp maybe_put_query(transformed_params, %{}), do: transformed_params

  def search_data_structures(params, claims, permission, page \\ 0, size \\ 50)

  def search_data_structures(params, %Claims{} = claims, permission, page, size) do
    query_data = ElasticDocumentProtocol.query_data(%DataStructureVersion{})
    query = build_query(claims, permission, params, query_data)
    sort = Map.get(params, "sort", ["_score", "name.raw"])

    do_search(
      %{
        query: query,
        sort: sort,
        from: page * size,
        size: size,
        _source: %{excludes: ["embeddings"]}
      },
      params
    )
  end

  defp build_query(%Claims{} = claims, permission, %{} = params, %{} = query_data) do
    claims
    |> search_permissions(permission)
    |> Query.build_query(params, query_data)
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
