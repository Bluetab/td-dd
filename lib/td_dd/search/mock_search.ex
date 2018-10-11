defmodule TdDd.Search.MockSearch do
  @moduledoc false

  alias Poison
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure

  def put_search(_something) do
  end

  def delete_search(_something) do
  end

  def search("data_structure", %{query: %{bool: %{must: %{match_all: %{}}}}}) do
    DataStructures.list_data_structures()
    |> Enum.map(&DataStructure.search_fields(&1))
    |> Enum.map(&%{_source: &1})
    |> Poison.encode!()
    |> Poison.decode!()
    |> search_results()
  end

  defp search_results(results) do
    %{results: results, total: Enum.count(results)}
  end

  def get_filters(_query) do
    %{
      "system" => ["SAP", "SAS"],
      "name" => ["KNA1", "KNB1"]
    }
  end
end
