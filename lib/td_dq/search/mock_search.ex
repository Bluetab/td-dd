defmodule TdDq.Search.MockSearch do
  @moduledoc false

  alias Poison
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
    |> Poison.encode!()
    |> Poison.decode!()
    |> search_results()
  end

  defp search_results(results) do
    %{results: results, aggregations: %{}, total: Enum.count(results)}
  end
end
