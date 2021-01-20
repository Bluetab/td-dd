defmodule TdDd.ElasticsearchMock do
  @moduledoc """
  A mock for elasticsearch supporting Data Dictionary queries.
  """

  @behaviour Elasticsearch.API

  alias Elasticsearch.Document
  alias HTTPoison.Response
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Search.Store

  require Logger

  @impl true
  def request(_config, :get, "/_cat/indices?format=json", _data, _opts) do
    {:ok, %Response{status_code: 200, body: []}}
  end

  @impl true
  def request(_config, :put, "/_template/structures", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/_aliases", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, _method, "/structures-" <> _suffix, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/structures/_doc/_bulk", _data, _opts) do
    body = %{"took" => 10, "items" => [], "errors" => false}
    {:ok, %Response{status_code: 200, body: body}}
  end

  @impl true
  def request(_config, :post, "/structures/_search", data, _opts) do
    data
    |> do_search()
    |> search_results(data)
  end

  @impl true
  def request(_config, :post, "/structures/_search?scroll=1m", data, _opts) do
    do_scroll(data)
  end

  @impl true
  def request(_config, :post, "/_search/scroll", data, _opts) do
    data
    |> decode_scroll_id()
    |> do_scroll()
  end

  @impl true
  def request(_config, :delete, "/structures/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{result: "deleted"}}}
  end

  @impl true
  def request(_config, method, url, data, _opts) do
    Logger.warn("#{method} #{url} #{Jason.encode!(data)}")
    search_results([])
  end

  defp do_scroll(scroll_params) do
    scroll_params
    |> do_search()
    |> search_results(scroll_params)
    |> case do
      {:ok, %Response{status_code: 200, body: body}} ->
        body = Map.put(body, "_scroll_id", encode_scroll_id(scroll_params))
        {:ok, %Response{status_code: 200, body: body}}
    end
  end

  defp do_search(%{query: query} = params) do
    from = Map.get(params, :from, 0)
    size = Map.get(params, :size, 10)

    query
    |> do_query()
    |> Enum.drop(from)
    |> Enum.take(size)
  end

  defp do_query(%{bool: bool}) do
    do_bool_query(bool)
  end

  defp do_query(%{term: term}) do
    do_term_query(term)
  end

  defp do_bool_query(bool) do
    f = create_bool_filter(bool)
    f.([])
  end

  defp do_term_query(term) do
    f = create_term_filter(term)

    list_documents()
    |> Enum.filter(fn doc -> f.(doc) end)
  end

  defp create_must([]), do: fn x -> x end

  defp create_must(must) when is_list(must) do
    fns = Enum.map(must, &create_must/1)

    fn acc ->
      Enum.reduce(fns, acc, fn f, acc -> f.(acc) end)
    end
  end

  defp create_must(%{match_all: _}) do
    fn _acc ->
      list_documents()
    end
  end

  defp create_must(%{query_string: query_string}) do
    f = create_query_string_query(query_string)

    fn _acc ->
      list_documents()
      |> Enum.filter(&f.(&1))
    end
  end

  defp create_must(%{multi_match: multi_match}) do
    f = create_multi_match(multi_match)

    fn _acc ->
      list_documents()
      |> Enum.filter(&f.(&1))
    end
  end

  defp create_filter([]), do: fn _ -> true end

  defp create_filter(filters) when is_list(filters) do
    fns = Enum.map(filters, &create_filter/1)

    fn el ->
      Enum.all?(fns, fn f -> f.(el) end)
    end
  end

  defp create_filter(%{bool: bool}) do
    create_bool_filter(bool)
  end

  defp create_filter(%{term: term}) do
    create_term_filter(term)
  end

  defp create_filter(%{terms: terms}) do
    create_terms_filter(terms)
  end

  defp create_term_filter(%{system_id: system_id}) do
    fn doc -> doc.system_id == system_id end
  end

  defp create_term_filter(%{domain_ids: domain_id}) do
    fn doc ->
      domain_ids =
        doc
        |> Map.get(:domain_ids, [])

      Enum.member?(domain_ids, domain_id)
    end
  end

  defp create_terms_filter(%{"system.name.raw" => values}) do
    fn doc ->
      value =
        doc
        |> Map.get(:system)

      Enum.member?(values, value)
    end
  end

  defp create_terms_filter(%{"type.raw" => values}) do
    fn doc ->
      value =
        doc
        |> Map.get(:type)

      Enum.member?(values, value)
    end
  end

  defp create_terms_filter(%{confidential: values}) do
    fn doc ->
      value =
        doc
        |> Map.get(:confidential)

      Enum.member?(values, value)
    end
  end

  defp create_must_not([]), do: fn _ -> false end

  defp create_must_not(must_not) when is_list(must_not) do
    fns = Enum.map(must_not, &create_must_not/1)

    fn el -> Enum.any?(fns, fn f -> f.(el) end) end
  end

  defp create_must_not(%{exists: exists}), do: create_exists_filter(exists)

  defp create_must_not(%{term: term}) do
    create_term_filter(term)
  end

  defp create_should([]), do: fn _ -> true end

  defp create_should(should) when is_list(should) do
    fns = Enum.map(should, &create_should/1)

    fn el ->
      Enum.any?(fns, fn f -> f.(el) end)
    end
  end

  defp create_should(%{bool: bool}) do
    create_bool_filter(bool)
  end

  defp create_multi_match(%{fields: fields, query: query, type: type}) do
    fns = Enum.map(fields, &create_field_match(&1, query, type))

    fn el ->
      Enum.any?(fns, fn f -> f.(el) end)
    end
  end

  defp create_field_match("name^2", query, "phrase_prefix") do
    fn doc ->
      doc
      |> Map.get(:name, "")
      |> String.downcase()
      |> String.starts_with?(String.downcase(query))
    end
  end

  defp create_field_match("system.name", query, "phrase_prefix") do
    fn doc ->
      doc
      |> Map.get(:system, %{})
      |> Map.get(:name, "")
      |> String.starts_with?(String.downcase(query))
    end
  end

  defp create_field_match("data_fields.name", query, "phrase_prefix") do
    fn doc ->
      doc
      |> Map.get(:data_fields, [])
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.map(&String.downcase/1)
      |> Enum.any?(&String.starts_with?(&1, String.downcase(query)))
    end
  end

  defp create_field_match("path.text", query, "phrase_prefix") do
    fn doc ->
      doc
      |> Map.get(:path, [])
      |> Enum.any?(&String.starts_with?(&1, query))
    end
  end

  defp create_field_match("description", query, "phrase_prefix") do
    fn doc ->
      doc
      |> Map.get(:description, "")
      |> String.starts_with?(String.downcase(query))
    end
  end

  defp create_field_match("df_content.*", query, "phrase_prefix") do
    fn doc ->
      doc
      |> Map.get(:df_content, %{})
      |> Map.values()
      |> Enum.any?(&String.starts_with?(&1, String.downcase(query)))
    end
  end

  defp create_field_match("name.ngram", query, _) do
    ngrams = ngrams(query, 3)

    fn doc ->
      doc
      |> Map.get(:name, "")
      |> ngrams(3)
      |> Enum.any?(fn ngram -> Enum.member?(ngrams, ngram) end)
    end
  end

  defp ngrams(str, size) do
    str
    |> String.downcase()
    |> String.replace(~r/\s/, "")
    |> String.to_charlist()
    |> Enum.chunk_every(size, 1, :discard)
    |> Enum.map(&to_string/1)
  end

  defp create_bool_filter(bool) do
    [filters, must, must_not, should] =
      [:filter, :must, :must_not, :should]
      |> Enum.map(&get_bool_clauses(bool, &1))

    filter = create_filter(filters)
    must_not = create_must_not(must_not)
    should = create_should(should)
    must = create_must(must)

    fn acc ->
      acc
      |> wrap()
      |> must.()
      |> Enum.reject(fn el -> must_not.(el) end)
      |> Enum.filter(fn el -> filter.(el) end)
      |> Enum.filter(fn el -> should.(el) end)
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

  defp create_exists_filter(%{field: field}) do
    fn doc ->
      doc
      |> Map.get(String.to_atom(field))
      |> exists?()
    end
  end

  defp exists?(nil), do: false
  defp exists?([]), do: false
  defp exists?(_), do: true

  defp create_query_string_query(%{query: query}) do
    create_query_string_query(query)
  end

  defp create_query_string_query(query) do
    case String.split(query, ":") do
      [field_spec, query] ->
        create_query_string_query(field_spec, query)
    end
  end

  defp create_query_string_query("xcontent.\\*", query) do
    fn doc -> matches_query?(doc, [:content], query) end
  end

  defp matches_query?(structure, fields, query) do
    case Regex.run(~r/^\(\"(.*)\"\)$/, query, capture: :all_but_first) do
      [q] ->
        fields
        |> Enum.any?(fn field ->
          structure
          |> Map.get(field)
          |> Jason.encode!()
          |> String.downcase()
          |> String.contains?(String.downcase(q))
        end)

      _ ->
        raise("mock not implemented for #{query}")
    end
  end

  defp list_documents do
    Store.transaction(fn ->
      DataStructureVersion
      |> Store.stream()
      |> Enum.map(&Document.encode/1)
    end)
  end

  defp search_results(hits, query \\ %{}) do
    results =
      hits
      |> Enum.map(&%{_source: &1})
      |> Jason.encode!()
      |> Jason.decode!()

    body = %{
      "hits" => %{"hits" => results, "total" => Enum.count(results)},
      "aggregations" => %{},
      "query" => query
    }

    {:ok, %Response{status_code: 200, body: body}}
  end

  defp encode_scroll_id(%{from: from, size: size} = params) do
    params
    |> Map.put(:from, size + from)
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp decode_scroll_id(%{"scroll_id" => scroll_id}) do
    decode_scroll_id(scroll_id)
  end

  defp decode_scroll_id(scroll_id) do
    scroll_id
    |> Base.decode64!()
    |> Jason.decode!(keys: :atoms)
  end
end
