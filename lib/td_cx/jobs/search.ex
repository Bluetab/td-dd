defmodule TdCx.Jobs.Search do
  @moduledoc """
  Helper module to construct job search queries.
  """

  alias TdCore.Search
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCore.Search.Query
  alias TdCx.Jobs.Job
  alias Truedat.Auth.Claims

  @index :jobs
  @accepted_wildcards ["\"", ")"]

  def get_filter_values(%Claims{role: role}, params) when role in ["admin", "service"] do
    query_data = %{aggs: aggs} = fetch_query_data(params)
    opts = Keyword.new(query_data)

    query = Query.build_query(%{match_all: %{}}, params, opts)
    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end

  def get_filter_values(_, _), do: %{}

  def search_jobs(params, claims, page \\ 0, size \\ 50)

  # Admin or service account search
  def search_jobs(params, %Claims{role: role}, page, size) when role in ["admin", "service"] do
    query_data = fetch_query_data(params)
    opts = Keyword.new(query_data)

    query = Query.build_query(%{match_all: %{}}, params, opts)
    sort = Map.get(params, "sort", ["_score", "external_id.raw"])

    %{
      from: page * size,
      size: size,
      query: query,
      sort: sort
    }
    |> do_search()
  end

  # Regular users cannot search jobs, return an empty response
  def search_jobs(_params, _claims, _page, _size),
    do: %{results: [], aggregations: %{}, total: 0}

  defp do_search(search) do
    {:ok, response} = Search.search(search, @index)

    transform_response(response)
  end

  defp transform_response({:ok, response}), do: transform_response(response)
  defp transform_response({:error, _} = response), do: response

  defp transform_response(%{results: results} = response) do
    results = Enum.map(results, &Map.get(&1, "_source"))
    %{response | results: results}
  end

  defp fetch_query_data(params) do
    %Job{}
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
    %{simple_query_string: %{fields: fields, quote_field_suffix: ".exact"}}
  end
end
