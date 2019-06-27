defmodule TdDq.Search.MockSearch do
  @moduledoc false

  alias Jason, as: JSON
  alias TdDq.Rules
  alias TdDq.Rules.Rule

  def put_searchable(_something) do
  end

  def delete_searchable(_something) do
  end

  def search("quality_rule", %{query: %{bool: %{must: %{match_all: %{}}}}}) do
    Rules.list_all_rules()
    |> Enum.map(&Rule.search_fields(&1))
    |> Enum.map(&%{_source: &1})
    |> JSON.encode!()
    |> JSON.decode!()
    |> search_results()
  end

  def get_filters("quality_rule", params) do
    get_filters(params)
  end

  def get_filters(%{bool: %{should: should}}) do
    should
    |> hd
    |> Map.get(:bool, %{})
    |> Map.get(:filter, [])
    |> get_filters()
  end

  def get_filters(query) when is_map(query) do
    query
    |> Map.get(:query, %{})
    |> Map.get(:bool, %{})
    |> Map.get(:filter, [])
    |> get_filters()
  end

  def get_filters([]), do: %{}

  def get_filters(filters) do
    filters
    |> Enum.map(&Map.get(&1, :terms))
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.reduce(%{}, fn x, acc -> Map.merge(acc, x) end)
  end

  defp search_results(results) do
    %{results: results, aggregations: %{}, total: Enum.count(results)}
  end
end
