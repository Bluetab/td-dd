defmodule TdDd.Systems.SystemSearch do
  @moduledoc """
  The Systems context.
  """
  alias TdDd.DataStructures.Search
  alias TdDd.Systems
  alias Truedat.Auth.Claims

  def search_systems(%Claims{role: role} = claims, permission, params)
      when role in ["admin", "service"] do
    get_systems_with_count(claims, permission, params)
  end

  def search_systems(%Claims{} = claims, permission, params) do
    systems_with_count = get_systems_with_count(claims, permission, params)
    Enum.filter(systems_with_count, fn system -> system.structures_count.count > 0 end)
  end

  defp entry(%{"doc_count" => count, "types" => %{"buckets" => buckets}}) do
    types =
      Enum.map(buckets, fn %{"key" => key, "doc_count" => value} -> %{name: key, count: value} end)

    %{types: types, count: count}
  end

  defp entry(_), do: %{}

  defp entries_by_system_id(%{"system_id" => %{"buckets" => buckets}}) do
    Map.new(buckets, fn %{"key" => key} = entry -> {key, entry(entry)} end)
  end

  defp entries_by_system_id(_), do: %{}

  def get_systems_with_count(%Claims{} = claims, _permission, _params) do
    agg_terms = %{
      "system_id" => %{
        terms: %{field: "system_id", size: 200},
        aggs: %{"types" => %{terms: %{field: "type.raw", size: 50}}}
      }
    }

    entries_by_system_id =
      case Search.get_aggregations(claims, agg_terms) do
        {:ok, %{aggregations: aggregations}} -> entries_by_system_id(aggregations)
        _ -> %{}
      end

    systems = Systems.list_systems()

    Enum.map(systems, fn %{id: id} = system ->
      case Map.get(entries_by_system_id, id) do
        nil -> Map.put(system, :structures_count, %{count: 0})
        structures_count -> Map.put(system, :structures_count, structures_count)
      end
    end)
  end
end
