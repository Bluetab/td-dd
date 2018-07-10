defmodule TdDd.Search.MockSearch do
  @moduledoc false

  alias Poison
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure

  def put_search(_something) do
  end

  # def delete_search(_something) do
  # end
  #
  # def search("business_concept", %{query: %{bool: %{must: %{match_all: %{}}}}}) do
  #   DataStructures.list_all_business_concept_versions()
  #   |> Enum.map(&DataStructure.search_fields(&1))
  #   |> Enum.map(&%{_source: &1})
  #   |> Poison.encode!()
  #   |> Poison.decode!()
  # end
  #
  # def search("business_concept", %{query: %{term: %{business_concept_id: business_concept_id}}}) do
  #   DataStructures.list_all_business_concept_versions()
  #   |> Enum.filter(&(&1.business_concept_id == business_concept_id))
  #   |> Enum.map(&DataStructure.search_fields(&1))
  #   |> Enum.map(&%{_source: &1})
  #   |> Poison.encode!()
  #   |> Poison.decode!()
  # end
  #
  # def search("business_concept", %{
  #       query: %{bool: %{must: %{simple_query_string: %{query: query}}}}
  #     }) do
  #   DataStructures.list_all_business_concept_versions()
  #   |> Enum.map(&DataStructure.search_fields(&1))
  #   |> Enum.filter(&matches(&1, query))
  #   |> Enum.map(&%{_source: &1})
  #   |> Poison.encode!()
  #   |> Poison.decode!()
  # end
  #
  # def search("business_concept", %{
  #   query: _query,
  #   sort: _sort,
  #   size: _size
  # }) do
  #   default_params_map = %{:link_count => 0, :q_rule_count => 0}
  #   DataStructures.list_all_business_concept_versions()
  #     |> Enum.map(&DataStructure.search_fields(&1))
  #     |> Enum.map(fn(bv) ->
  #       Map.merge(bv, default_params_map, fn _k, v1, v2 ->
  #         v1 || v2
  #       end)
  #     end)
  # end
  #
  # defp matches(string, query) when is_bitstring(string) do
  #   String.starts_with?(string, query)
  # end
  #
  # defp matches(list, query) when is_list(list) do
  #   list |> Enum.any?(&matches(&1, query))
  # end
  #
  # defp matches(map, query) when is_map(map) do
  #   map |> Map.values() |> matches(query)
  # end
  #
  # defp matches(_item, _query), do: false
  #
  # def get_filters(_query) do
  #   %{
  #     "domain" => ["Domain 1", "Domain 2"],
  #     "dynamic_field" => ["Value 1", "Value 2"]
  #   }
  # end
end
