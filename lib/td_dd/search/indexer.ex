defmodule TdDd.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """
  alias Jason, as: JSON
  alias TdDd.Search
  alias TdDd.Search.Cluster
  alias TdDd.Search.Mappings

  def reindex(:all) do
    template =
      Mappings.get_mappings()
      |> Map.put(:index_patterns, "structures-*")
      |> JSON.encode!()

    {:ok, _} = Elasticsearch.put(Cluster, "/_template/structures", template)

    Search.put_bulk_search(:all)
  end

  def reindex(ids) do
    Search.put_bulk_search(ids)
  end
end
