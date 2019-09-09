defmodule TdDd.Search.MockSearch do
  @moduledoc false

  alias Jason, as: JSON
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure

  def put_search(_something) do
  end

  def delete_search(_something) do
  end

  def search("data_structure", %{query: %{bool: %{filter: filters, must: %{match_all: %{}}}}}) do
    template_list = TemplateCache.list_by_scope!("dd")
    data_structures = DataStructures.list_data_structures()

    results =
      data_structures
      |> Enum.map(&DataStructure.search_fields(&1))
      |> apply_filters(filters)
      |> Enum.map(&%{_source: &1})
      |> JSON.encode!()
      |> JSON.decode!()

    aggregations = get_aggregations(data_structures, template_list)

    search_results(results, aggregations)
  end

  defp apply_filters(dss, []), do: dss

  defp apply_filters(dss, [filter | filters]) do
    dss
    |> apply_filter(filter)
    |> apply_filters(filters)
  end

  defp apply_filter(dss, %{term: %{system_id: system_id}}) do
    Enum.filter(dss, &(Map.get(&1, :system_id) == system_id))
  end

  defp apply_filter(dss, %{bool: %{must_not: %{exists: %{field: field}}}}) do
    Enum.filter(dss, &is_missing?(&1, field))
  end

  defp apply_filter(dss, %{terms: %{"ou.raw" => values}}) do
    Enum.filter(dss, &Enum.member?(values, Map.get(&1, :ou)))
  end

  defp apply_filter(dss, %{terms: %{"type.raw" => values}}) do
    Enum.filter(dss, &Enum.member?(values, Map.get(&1, :type)))
  end

  defp is_missing?(ds, field) do
    case Map.get(ds, String.to_atom(field)) do
      nil -> true
      [] -> true
      "" -> true
      _ -> false
    end
  end

  defp get_aggregations([], _), do: %{}
  defp get_aggregations(_, []), do: %{}

  defp get_aggregations(data_structures, template_list) do
    indexed_structures =
      data_structures
      |> Enum.map(&DataStructure.search_fields/1)

    agg_fields =
      indexed_structures
      |> Enum.map(&Map.take(&1, [:ou, :system, :type, :df_content]))

    types = get_aggegation_values_for_field(agg_fields, :type)
    domains = get_aggegation_values_for_field(agg_fields, :ou)
    content = dynamic_content(indexed_structures, template_list)

    %{"ou.raw" => domains, "type.raw" => types}
    |> Map.merge(content)
  end

  defp get_aggegation_values_for_field(agg_fields, field) do
    agg_fields
    |> Enum.map(&Map.get(&1, field))
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.uniq()
  end

  defp dynamic_content(data_structures, template_list) do
    template_names =
      template_list
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.filter(&(not is_nil(&1)))

    data_structures
    |> Enum.filter(&Enum.member?(template_names, Map.get(&1, :type)))
    |> Enum.map(&Map.get(&1, :df_content))
    |> Enum.filter(& &1)
    |> Enum.flat_map(&Enum.to_list/1)
    |> Enum.reduce(%{}, &update_content_values(&1, &2))
  end

  defp update_content_values({key, value}, acc) do
    updated_content_values =
      acc
      |> Map.get(key, [])
      |> Kernel.++([value])
      |> Enum.uniq()

    Map.put(acc, key, updated_content_values)
  end

  defp search_results(results, aggregations) do
    %{results: results, aggregations: aggregations, total: Enum.count(results)}
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
end
