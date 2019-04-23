defmodule TdDd.Search.MockSearch do
  @moduledoc false

  alias Poison
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Search.Aggregations

  @df_cache Application.get_env(:td_dd, :df_cache)

  def put_search(_something) do
  end

  def delete_search(_something) do
  end

  def search("data_structure", %{query: %{bool: %{must: %{match_all: %{}}}}}) do
    template_list = @df_cache.list_templates()
    data_structures = DataStructures.list_data_structures()

    results =
      data_structures
      |> Enum.map(&DataStructure.search_fields(&1))
      |> Enum.map(&%{_source: &1})
      |> Poison.encode!()
      |> Poison.decode!()

    aggregations = get_aggregations(data_structures, template_list)

    search_results(results, aggregations)
  end

  defp get_aggregations([], _), do: %{}
  defp get_aggregations(_, []), do: %{}

  defp get_aggregations(data_structures, template_list) do
    agg_fields = Enum.map(data_structures, &Map.take(&1, [:ou, :system, :type, :df_content]))

    types = get_aggegation_values_for_field(agg_fields, :type)
    domains = get_aggegation_values_for_field(agg_fields, :ou)
    content = dynamic_content(data_structures, template_list)

    %{"ou.raw" => domains, "type.raw" => types} |> Map.merge(content)
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
    |> Enum.map(&Enum.to_list(&1))
    |> List.flatten()
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

  def get_filters(_query) do
    %{
      "system" => ["SAP", "SAS"],
      "name" => ["KNA1", "KNB1"]
    }
  end
end
