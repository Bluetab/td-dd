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

  def get_filter_values(%Claims{role: role}, params) when role in ["admin", "service"] do
    query = Query.build_query(%{match_all: %{}}, params)

    aggs = ElasticDocumentProtocol.aggregations(%Job{})

    search = %{query: query, aggs: aggs, size: 0}

    Search.get_filters(search, @index)
  end

  def get_filter_values(_, _), do: %{}

  def search_jobs(params, claims, page \\ 0, size \\ 50)

  # Admin or service account search
  def search_jobs(params, %Claims{role: role}, page, size) when role in ["admin", "service"] do
    aggs = ElasticDocumentProtocol.aggregations(%Job{})

    query = Query.build_query(%{match_all: %{}}, params, aggs)

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
end
