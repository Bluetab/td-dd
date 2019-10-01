defmodule TdDq.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Jason, as: JSON
  alias TdDq.Rules
  alias TdDq.Search
  alias TdDq.Search.Cluster
  alias TdDq.Search.RuleMappings

  def reindex(:rule) do
    template =
      RuleMappings.get_mappings()
      |> Map.put(:index_patterns, "rules-*")
      |> JSON.encode!()

    {:ok, _} = Elasticsearch.put(Cluster, "/_template/rules", template)

    Search.put_bulk_search(:rule)
  end

  def reindex(ids, :rule) do
    ids
    |> Rules.list_rules()
    |> Search.put_bulk_search(:rule)
  end

  def delete(ids, :rule) do
    Search.put_bulk_delete(ids, :rule)
  end
end
