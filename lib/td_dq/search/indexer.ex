defmodule TdDq.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Jason, as: JSON
  alias TdDq.ESClientApi
  alias TdDq.Search
  alias TdDq.Search.RuleMappings

  def reindex(index_name, items) do
    ESClientApi.delete!(index_name)
    mapping = RuleMappings.get_mappings()
    %{status_code: 200} = ESClientApi.put!(index_name, mapping |> JSON.encode!())
    Search.put_bulk_search(items)
  end
end
