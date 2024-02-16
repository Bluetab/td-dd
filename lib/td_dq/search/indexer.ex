defmodule TdDq.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index.Bulk
  alias TdCache.Redix
  alias TdDd.Search.Cluster
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Search.Mappings
  alias TdDq.Search.Store
  alias Truedat.Search.Indexer

  require Logger

  @rule_index :rules
  @implementation_index :implementations
  @action "index"

  def reindex_rules(:all) do
    do_reindex_all(Mappings.get_rule_mappings(), @rule_index)
  end

  def reindex_rules(ids) do
    do_reindex(Rule, @rule_index, ids)
  end

  def reindex_implementations(:all) do
    do_reindex_all(Mappings.get_implementation_mappings(), @implementation_index)
  end

  def reindex_implementations(ids) do
    do_reindex(Implementation, @implementation_index, ids)
  end

  defp do_reindex_all(mappings, index) do
    alias_name = Cluster.alias_name(index)

    mappings
    |> Map.put(:index_patterns, "#{alias_name}-*")
    |> Jason.encode!()
    |> Indexer.put_template(Cluster, alias_name)
    |> Indexer.maybe_hot_swap(Cluster, alias_name)
  end

  defp do_reindex(schema, index, ids) do
    Store.transaction(fn ->
      schema
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, index, "index"))
      |> Stream.chunk_every(Cluster.setting(index, :bulk_page_size))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{index}/_doc/_bulk", &1))
      |> Stream.map(&Indexer.log_bulk_post(index, &1, @action))
      |> Stream.run()
    end)
  end

  def delete_rules(ids) do
    delete(ids, @rule_index)
  end

  def delete_implementations(ids) do
    delete(ids, @implementation_index)
  end

  defp delete(ids, index) do
    alias_name = Cluster.alias_name(index)
    Enum.map(ids, &Elasticsearch.delete_document(Cluster, &1, alias_name))
  end

  def verify_indices do
    alias_rule = Cluster.alias_name(@rule_index)
    alias_implementation = Cluster.alias_name(@implementation_index)

    unless Indexer.alias_exists?(Cluster, alias_rule) and
             Indexer.alias_exists?(Cluster, alias_implementation) do
      if can_reindex?() do
        Indexer.delete_existing_index(Cluster, alias_rule)
        Indexer.delete_existing_index(Cluster, alias_implementation)

        Timer.time(
          fn -> reindex_rules(:all) end,
          fn millis, _ -> Logger.info("Created index #{alias_rule} in #{millis}ms") end
        )

        Timer.time(
          fn -> reindex_implementations(:all) end,
          fn millis, _ -> Logger.info("Created index #{alias_implementation} in #{millis}ms") end
        )
      else
        Logger.warn("Another process is migrating")
      end
    end
  end

  # Ensure only one instance of dq is reindexing by creating a lock in Redis
  defp can_reindex? do
    Redix.command!(["SET", "TdDq.Search.Indexer:LOCK", node(), "NX", "EX", 3600]) == "OK"
  end
end
