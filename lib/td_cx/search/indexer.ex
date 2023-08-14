defmodule TdCx.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """
  alias Elasticsearch.Index.Bulk
  alias Truedat.Search.Indexer
  alias TdCache.Redix
  alias TdCx.Jobs.Job
  alias TdCx.Search.Mappings
  alias TdCx.Search.Store
  alias TdDd.Search.Cluster

  require Logger

  @action "index"

  def reindex(:all) do
    alias_name = Cluster.alias_name(:jobs)

    Mappings.get_mappings()
    |> Map.put(:index_patterns, "#{alias_name}-*")
    |> Jason.encode!()
    |> Indexer.put_template(Cluster, alias_name)
    |> Indexer.maybe_hot_swap(Cluster, alias_name)
  end

  def reindex(ids) do
    alias_name = Cluster.alias_name(:jobs)

    Store.transaction(fn ->
      Job
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, alias_name, @action))
      |> Stream.chunk_every(Cluster.setting(:jobs, :bulk_page_size))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{alias_name}/_doc/_bulk", &1))
      |> Stream.map(&Indexer.log_bulk_post(alias_name, &1, @action))
      |> Stream.run()
    end)
  end

  def delete(jobs) when is_list(jobs) do
    Enum.each(jobs, &delete/1)
  end

  def delete(job) do
    alias_name = Cluster.alias_name(:jobs)
    Elasticsearch.delete_document(Cluster, job, "#{alias_name}")
  end

  def verify_indices do
    alias_name = Cluster.alias_name(:jobs)

    unless Indexer.alias_exists?(Cluster, alias_name) do
      if can_reindex?() do
        Indexer.delete_existing_index(Cluster, alias_name)

        Timer.time(
          fn -> reindex(:all) end,
          fn millis, _ -> Logger.info("Created index #{alias_name} in #{millis}ms") end
        )
      else
        Logger.warn("Another process is migrating")
      end
    end
  end

  # Ensure only one instance of cx is reindexing by creating a lock in Redis
  defp can_reindex? do
    Redix.command!(["SET", "TdCx.Search.Indexer:LOCK", node(), "NX", "EX", 3600]) == "OK"
  end
end
