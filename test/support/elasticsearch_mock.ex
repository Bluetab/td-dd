defmodule TdDq.ElasticsearchMock do
  @moduledoc """
  A mock for elasticsearch supporting Business Glossary queries.
  """

  @behaviour Elasticsearch.API

  alias Elasticsearch.Document
  alias HTTPoison.Response
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
        %{query: %{bool: %{filter: filter}}} = params,
        _opts
      ) do
    aggregations = get_aggregations(filter)
    Implementation |> do_search(params) |> search_results(aggregations)
  end

  @impl true
  def request(
        _config,
        :post,
        "/rules/_search",
        %{query: %{bool: %{filter: filter}}} = params,
        _opts
      ) do
    aggregations = get_aggregations(filter)
    Rule |> do_search(params) |> search_results(aggregations)
  end

  @impl true
  def request(
        _config,
        :post,
        "/rules/_search",
        %{} = params,
        _opts
      ) do
    Rule |> do_search(params) |> search_results()
  end

  @impl true
  def request(_config, :delete, "/rules/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: Jason.encode!(%{result: "deleted"})}}
  end

  @impl true
  def request(_config, :delete, "/implementations/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: Jason.encode!(%{result: "deleted"})}}
  end

  @impl true
  def request(_config, method, url, data, _opts) do
    Logger.warn("#{method} #{url} #{Jason.encode!(data)}")
    search_results([])
  end

  def get_aggregations(%{bool: %{should: should}}) do
    should
    |> hd
    |> Map.get(:bool, %{})
    |> Map.get(:filter, [])
    |> get_aggregations()
  end

  def get_aggregations([]), do: %{}

  def get_aggregations(filters) do
    filters
    |> Enum.map(&Map.get(&1, :terms))
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.reduce(%{}, fn x, acc ->
      format =
        Enum.into(x, %{}, fn {k, v} -> {k, %{"buckets" => Enum.map(v, &%{"key" => &1})}} end)

      Map.merge(acc, format)
    end)
  end

  defp do_search(schema, %{query: query} = params) do
    from = Map.get(params, :from, 0)
    size = Map.get(params, :size, 10)

    query
    |> do_query(schema)
    |> Enum.drop(from)
    |> Enum.take(size)
  end

  defp list_documents(schema) do
    Store.transaction(fn ->
      schema
      |> Store.stream()
      |> Enum.map(&Document.encode/1)
      |> Enum.map(&Jason.encode!/1)
      |> Enum.map(&Jason.decode!/1)
    end)
  end

  defp search_results(hits, aggregations \\ %{}) do
    results = Enum.map(hits, &%{"_source" => &1})

    body = %{
      "hits" => %{"hits" => results, "total" => Enum.count(results)},
      "aggregations" => aggregations
    }

    {:ok, %Response{status_code: 200, body: body}}
  end

  defp do_query(%{bool: bool}, schema) do
    do_bool_query(bool, schema)
  end

  defp do_bool_query(bool, schema) do
    f = create_bool_filter(bool, schema)
    f.([])
  end

  defp create_bool_filter(bool, schema) do
    [filters, must, must_not, _should] =
      [:filter, :must, :must_not, :should]
      |> Enum.map(&get_bool_clauses(bool, &1))

    filter = create_filter(filters, schema)
    must_not = create_must_not(must_not)
    # should = create_should(should)
    must = create_must(must, schema)

    fn acc ->
      acc
      |> wrap()
      |> must.()
      |> Enum.reject(fn el -> must_not.(el) end)
      |> Enum.filter(fn el -> filter.(el) end)
      # |> Enum.filter(fn el -> should.(el) end)
      |> unwrap(acc)
    end
  end

  defp wrap(els) when is_list(els), do: els
  defp wrap(el), do: [el]

  defp unwrap(els, list) when is_list(list), do: els
  defp unwrap([h | _t], _), do: h
  defp unwrap([], _), do: false

  defp get_bool_clauses(bool, clause) do
    case Map.get(bool, clause, []) do
      [] -> []
      l when is_list(l) -> l
      el -> [el]
    end
  end

  defp create_filter([], _schema), do: fn _ -> true end

  defp create_filter(filters, schema) when is_list(filters) do
    fns = Enum.map(filters, &create_filter(&1, schema))
    fn el -> Enum.all?(fns, fn f -> f.(el) end) end
  end

  defp create_filter(%{bool: bool}, schema) do
    create_bool_filter(bool, schema)
  end

  defp create_filter(%{term: term}, _schema) do
    create_term_filter(term)
  end

  defp create_filter(%{terms: terms}, _schema) do
    create_terms_filter(terms)
  end

  defp create_must([], _schema), do: fn x -> x end

  defp create_must(must, schema) when is_list(must) do
    fns = Enum.map(must, &create_must(&1, schema))

    fn acc ->
      Enum.reduce(fns, acc, fn f, acc -> f.(acc) end)
    end
  end

  defp create_must(%{match_all: _}, schema) do
    fn _acc -> list_documents(schema) end
  end

  defp create_must(%{exists: %{field: field}}, schema) do
    fn _acc ->
      schema
      |> list_documents()
      |> Enum.reject(&is_nil(Map.get(&1, field)))
    end
  end

  defp create_must_not([]), do: fn _ -> false end

  defp create_must_not(must_not) when is_list(must_not) do
    fns = Enum.map(must_not, &create_must_not/1)

    fn el -> Enum.any?(fns, fn f -> f.(el) end) end
  end

  defp create_must_not(%{exists: exists}), do: create_exists_filter(exists)

  defp create_exists_filter(%{field: field}) do
    fn doc ->
      doc
      |> Map.get(field)
      |> exists?()
    end
  end

  defp exists?(nil), do: false
  defp exists?([]), do: false
  defp exists?(_), do: true

  defp create_term_filter(%{} = term) when is_map(term) do
    term
    |> Map.to_list()
    |> create_term_filter()
  end

  defp create_term_filter([{key, value}]) do
    fn doc -> Map.get(doc, key) == value end
  end

  defp create_terms_filter(%{"execution.raw" => [false]}) do
    fn doc -> doc end
  end

  defp create_terms_filter(%{} = terms) when is_map(terms) do
    terms
    |> Map.to_list()
    |> create_terms_filter()
  end

  defp create_terms_filter([{key, values}]) do
    fn doc -> Map.get(doc, key) in values end
  end
end
