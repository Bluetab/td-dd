defmodule TdCx.ElasticsearchMock do
  @moduledoc """
  A mock for elasticsearch supporting Business Glossary queries.
  """

  @behaviour Elasticsearch.API

  alias HTTPoison.Response
  alias Jason, as: JSON

  require Logger

  @impl true
  def request(_config, :head, "/_alias/jobs", _data, _opts) do
    {:ok, %Response{status_code: 200, body: []}}
  end

  @impl true
  def request(_config, :get, "/_cat/indices?format=json", _data, _opts) do
    {:ok, %Response{status_code: 200, body: []}}
  end

  @impl true
  def request(_config, :put, "/_template/jobs", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/_aliases", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, _method, "/jobs-" <> _suffix, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/jobs/_doc/_bulk", _data, _opts) do
    body = %{"took" => 10, "items" => [], "errors" => false}
    {:ok, %Response{status_code: 200, body: body}}
  end

  @impl true
  def request(_config, :post, "/jobs/_search", data, _opts) do
    # data
    # |> do_search()
    # |> Enum.map(&Document.encode/1)
    # |> search_results(data)
    []
  end

  @impl true
  def request(_config, :delete, "/jobs/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{result: "deleted"}}}
  end

  @impl true
  def request(_config, method, url, data, _opts) do
    Logger.warn("#{method} #{url} #{JSON.encode!(data)}")
    # search_results([])
    []
  end

  # defp do_search(%{query: query} = params) do
  #   from = Map.get(params, :from, 0)
  #   size = Map.get(params, :size, 10)

  #   query
  #   |> do_query()
  #   |> Enum.drop(from)
  #   |> Enum.take(size)
  # end

  # defp do_query(%{bool: bool}) do
  #   do_bool_query(bool)
  # end

  # defp do_query(%{term: term}) do
  #   do_term_query(term)
  # end

  # defp do_bool_query(bool) do
  #   f = create_bool_filter(bool)
  #   f.([])
  # end

  # defp do_term_query(term) do
  #   f = create_term_filter(term)

  #   list_all_concepts()
  #   |> Enum.filter(fn c -> f.(c) end)
  # end

  # defp create_must([]), do: fn x -> x end

  # defp create_must(must) when is_list(must) do
  #   fns = Enum.map(must, &create_must/1)

  #   fn acc ->
  #     Enum.reduce(fns, acc, fn f, acc -> f.(acc) end)
  #   end
  # end

  # defp create_must(%{match_all: _}) do
  #   fn _acc ->
  #     list_all_concepts()
  #   end
  # end

  # defp create_must(%{query_string: query_string}) do
  #   f = create_query_string_query(query_string)

  #   fn _acc ->
  #     list_all_concepts()
  #     |> Enum.filter(&f.(&1))
  #   end
  # end

  # defp create_must(%{simple_query_string: %{query: query}}) do
  #   case Regex.run(~r/^(.*)\*/, query, capture: :all_but_first) do
  #     [prefix] -> create_prefix_query(prefix)
  #     _ -> raise("query #{query} is not mocked")
  #   end
  # end

  # defp create_prefix_query(prefix) do
  #   fn _acc ->
  #     list_all_concepts()
  #     |> Enum.filter(&matches_prefix?(&1, [:name], prefix))
  #   end
  # end

  # defp matches_prefix?(concept, fields, prefix) do
  #   fields
  #   |> Enum.any?(fn field ->
  #     concept
  #     |> Map.get(field)
  #     |> String.downcase()
  #     |> String.starts_with?(String.downcase(prefix))
  #   end)
  # end

  # defp create_filter([]), do: fn _ -> true end

  # defp create_filter(filters) when is_list(filters) do
  #   fns = Enum.map(filters, &create_filter/1)

  #   fn el ->
  #     Enum.all?(fns, fn f -> f.(el) end)
  #   end
  # end

  # defp create_filter(%{bool: bool}) do
  #   create_bool_filter(bool)
  # end

  # defp create_filter(%{term: term}) do
  #   create_term_filter(term)
  # end

  # defp create_filter(%{terms: terms}) do
  #   create_terms_filter(terms)
  # end

  # defp create_term_filter(%{status: status}) do
  #   fn c -> c.status == status end
  # end

  # defp create_term_filter(%{current: current}) do
  #   fn c -> c.current == current end
  # end

  # defp create_term_filter(%{business_concept_id: business_concept_id}) do
  #   fn c -> c.business_concept_id == business_concept_id end
  # end

  # defp create_term_filter(%{domain_ids: domain_id}) do
  #   fn c -> matches_domain_id(c, domain_id) end
  # end

  # def create_terms_filter(%{status: statuses}) do
  #   fn c -> Enum.member?(statuses, c.status) end
  # end

  # def create_terms_filter(%{"status" => statuses}) do
  #   fn c -> Enum.member?(statuses, c.status) end
  # end

  # def create_terms_filter(%{:"content._confidential.raw" => values}) do
  #   fn c ->
  #     value =
  #       c
  #       |> Map.get(:content, %{})
  #       |> Map.get("_confidential", "No")

  #     Enum.member?(values, value)
  #   end
  # end

  # defp create_must_not([]), do: fn _ -> false end

  # defp create_must_not(must_not) when is_list(must_not) do
  #   fns = Enum.map(must_not, &create_must_not/1)

  #   fn el ->
  #     Enum.any?(fns, fn f -> f.(el) end)
  #   end
  # end

  # defp create_must_not(%{term: term}) do
  #   create_term_filter(term)
  # end

  # defp create_should([]), do: fn _ -> true end

  # defp create_should(should) when is_list(should) do
  #   fns = Enum.map(should, &create_should/1)

  #   fn el ->
  #     Enum.any?(fns, fn f -> f.(el) end)
  #   end
  # end

  # defp create_should(%{bool: bool}) do
  #   create_bool_filter(bool)
  # end

  # defp create_bool_filter(bool) do
  #   [filters, must, must_not, should] =
  #     [:filter, :must, :must_not, :should]
  #     |> Enum.map(&get_bool_clauses(bool, &1))

  #   filter = create_filter(filters)
  #   must_not = create_must_not(must_not)
  #   should = create_should(should)
  #   must = create_must(must)

  #   fn acc ->
  #     acc
  #     |> wrap()
  #     |> must.()
  #     |> Enum.reject(fn el -> must_not.(el) end)
  #     |> Enum.filter(fn el -> filter.(el) end)
  #     |> Enum.filter(fn el -> should.(el) end)
  #     |> unwrap(acc)
  #   end
  # end

  # defp wrap(els) when is_list(els), do: els
  # defp wrap(el), do: [el]

  # defp unwrap(els, list) when is_list(list), do: els
  # defp unwrap([h | _t], _), do: h
  # defp unwrap([], _), do: false

  # defp get_bool_clauses(bool, clause) do
  #   case Map.get(bool, clause, []) do
  #     [] -> []
  #     l when is_list(l) -> l
  #     el -> [el]
  #   end
  # end

  # defp create_query_string_query(%{query: query}) do
  #   create_query_string_query(query)
  # end

  # defp create_query_string_query(query) do
  #   case String.split(query, ":") do
  #     [field_spec, query] ->
  #       create_query_string_query(field_spec, query)
  #   end
  # end

  # defp create_query_string_query("content.\\*", query) do
  #   fn c -> matches_query?(c, [:content], query) end
  # end

  # defp matches_query?(concept, fields, query) do
  #   case Regex.run(~r/^\(\"(.*)\"\)$/, query, capture: :all_but_first) do
  #     [q] ->
  #       fields
  #       |> Enum.any?(fn field ->
  #         concept
  #         |> Map.get(field)
  #         |> JSON.encode!()
  #         |> String.downcase()
  #         |> String.contains?(String.downcase(q))
  #       end)

  #     _ ->
  #       raise("mock not implemented for #{query}")
  #   end
  # end

  # defp matches_domain_id(%BusinessConceptVersion{} = bcv, domain_id) do
  #   bcv
  #   |> Document.encode()
  #   |> matches_domain_id(domain_id)
  # end

  # defp matches_domain_id(%{domain_ids: domain_ids}, domain_id) do
  #   domain_ids = MapSet.new(domain_ids, &"#{&1}")

  #   ["#{domain_id}"]
  #   |> MapSet.new()
  #   |> MapSet.disjoint?(domain_ids)
  #   |> (fn x -> not x end).()
  # end

  # defp list_all_concepts do
  #   BusinessConcepts.list_all_business_concept_versions()
  # end

  # defp search_results(hits, query \\ %{}) do
  #   results =
  #     hits
  #     |> Enum.map(&%{_source: &1})
  #     |> JSON.encode!()
  #     |> JSON.decode!()

  #   body = %{
  #     "hits" => %{"hits" => results, "total" => Enum.count(results)},
  #     "aggregations" => %{},
  #     "query" => query
  #   }

  #   {:ok, %Response{status_code: 200, body: body}}
  # end
end
