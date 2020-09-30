defmodule TdDq.ElasticsearchMock do
  @moduledoc """
  A mock for elasticsearch supporting Business Glossary queries.
  """

  @behaviour Elasticsearch.API

  alias Elasticsearch.Document
  alias HTTPoison.Response
  alias Jason, as: JSON
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Search.Store

  require Logger

  @impl true
  def request(_config, :get, "/_cat/indices?format=json", _data, _opts) do
    {:ok, %Response{status_code: 200, body: []}}
  end

  @impl true
  def request(_config, :put, "/_template/rules", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/_aliases", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, _method, "/rules-" <> _suffix, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/rules/_doc/_bulk", _data, _opts) do
    body = %{"took" => 10, "items" => [], "errors" => false}
    {:ok, %Response{status_code: 200, body: body}}
  end

  @impl true
  def request(_config, :post, "/implementations/_doc/_bulk", _data, _opts) do
    body = %{"took" => 10, "items" => [], "errors" => false}
    {:ok, %Response{status_code: 200, body: body}}
  end

  @impl true
  def request(
        _config,
        :post,
        "/implementations/_search",
        %{query: %{bool: %{must: %{match_all: %{}}, filter: filter}}},
        _opts
      ) do
    filters = get_filters(filter)
    Implementation |> do_search() |> search_results(filters)
  end

  @impl true
  def request(
        _config,
        :post,
        "/rules/_search",
        %{query: %{bool: %{must: %{match_all: %{}}, filter: filter}}},
        _opts
      ) do
    filters = get_filters(filter)
    do_search() |> search_results(filters)
  end

  @impl true
  def request(
        _config,
        :post,
        "/rules/_search",
        %{query: %{bool: %{must: %{match_all: %{}}}}},
        _opts
      ) do
    do_search() |> search_results()
  end

  @impl true
  def request(_config, :delete, "/rules/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: JSON.encode!(%{result: "deleted"})}}
  end

  @impl true
  def request(_config, :delete, "/implementations/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: JSON.encode!(%{result: "deleted"})}}
  end

  @impl true
  def request(_config, method, url, data, _opts) do
    Logger.warn("#{method} #{url} #{Jason.encode!(data)}")
    search_results([])
  end

  def get_filters(%{bool: %{should: should}}) do
    should
    |> hd
    |> Map.get(:bool, %{})
    |> Map.get(:filter, [])
    |> get_filters()
  end

  def get_filters([]), do: %{}

  def get_filters(filters) do
    filters
    |> Enum.map(&Map.get(&1, :terms))
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.reduce(%{}, fn x, acc ->
      format =
        Enum.into(x, %{}, fn {k, v} -> {k, %{"buckets" => Enum.map(v, &%{"key" => &1})}} end)

      Map.merge(acc, format)
    end)
  end

  defp do_search(schema \\ Rule) do
    list_documents(schema)
  end

  defp list_documents(schema) do
    Store.transaction(fn ->
      schema
      |> Store.stream()
      |> Enum.map(&Document.encode/1)
    end)
  end

  defp search_results(hits, filters \\ %{}) do
    results =
      hits
      |> Enum.map(&%{_source: &1})
      |> JSON.encode!()
      |> JSON.decode!()

    body = %{
      "hits" => %{"hits" => results, "total" => Enum.count(results)},
      "aggregations" => filters
    }

    {:ok, %Response{status_code: 200, body: body}}
  end
end
