defmodule TdDq.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias Jason, as: JSON
  alias TdCache.Redix
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Search.Cluster
  alias TdDq.Search.Mappings
  alias TdDq.Search.Store

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
    {:ok, _} =
      mappings
      |> Map.put(:index_patterns, "#{index}-*")
      |> JSON.encode!()
      |> put_template(index)

    Index.hot_swap(Cluster, index)
  end

  defp do_reindex(schema, index, ids) do
    Store.transaction(fn ->
      schema
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, index, "index"))
      |> Stream.chunk_every(bulk_page_size(index))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{index}/_doc/_bulk", &1))
      |> Stream.map(&log(&1, @action))
      |> Stream.run()
    end)
  end

  def delete_rules(ids) do
    delete(ids, @rule_index)
  end

  def delete_implementations(ids) do
    delete(ids, @implementation_index)
  end

  def migrate do
    if can_migrate?() do
      migrate_rules()
      migrate_implementations()
    end
  end

  defp migrate_rules do
    unless alias_exists?(@rule_index) do
      delete_existing_index("quality_rule")

      Timer.time(
        fn -> reindex_rules(:all) end,
        fn millis, _ -> Logger.info("Created index #{@rule_index} in #{millis}ms") end
      )
    end
  end

  defp migrate_implementations do
    unless alias_exists?(@implementation_index) do
      Timer.time(
        fn -> reindex_implementations(:all) end,
        fn millis, _ -> Logger.info("Created index #{@implementation_index} in #{millis}ms") end
      )
    end
  end

  defp bulk_page_size(index) do
    :td_dq
    |> Application.get_env(Cluster)
    |> Keyword.get(:indexes)
    |> Map.get(index)
    |> Map.get(:bulk_page_size)
  end

  defp put_template(template, name) do
    Elasticsearch.put(Cluster, "/_template/#{name}", template)
  end

  defp alias_exists?(name) do
    case Elasticsearch.head(Cluster, "/_alias/#{name}") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp delete(ids, index) do
    Enum.map(ids, &Elasticsearch.delete_document(Cluster, &1, index))
  end

  defp delete_existing_index(name) do
    case Elasticsearch.delete(Cluster, "/#{name}") do
      {:ok, _} ->
        Logger.info("Deleted index #{name}")

      {:error, %{status: 404}} ->
        :ok

      error ->
        error
    end
  end

  # Ensure only one instance of dq is reindexing by creating a lock in Redis
  defp can_migrate? do
    Redix.command!(["SET", "TdDq.Search.Indexer:LOCK", node(), "NX", "EX", 3600]) == "OK"
  end

  defp log({:ok, %{"errors" => false, "items" => items, "took" => took}}, _action) do
    Logger.info("Indexed #{Enum.count(items)} documents (took=#{took})")
  end

  defp log({:ok, %{"errors" => true} = response}, action) do
    first_error = response["items"] |> Enum.find(& &1[action]["error"])
    Logger.warn("Bulk indexing encountered errors #{inspect(first_error)}")
  end

  defp log({:error, error}, _action) do
    Logger.warn("Bulk indexing encountered errors #{inspect(error)}")
  end

  defp log(error, _action) do
    Logger.warn("Bulk indexing encountered errors #{inspect(error)}")
  end
end
