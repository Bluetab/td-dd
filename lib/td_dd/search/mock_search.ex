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
  end

end
