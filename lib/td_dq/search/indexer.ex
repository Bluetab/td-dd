defmodule TdDq.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias Jason, as: JSON
  alias TdCache.Redix
  alias TdDq.Rules.Rule
  alias TdDq.Search.Cluster
  alias TdDq.Search.Mappings
  alias TdDq.Search.Store

  require Logger

  @index :rules
  @action "index"

  def reindex(:all) do
    {:ok, _} =
      Mappings.get_mappings()
      |> Map.put(:index_patterns, "#{@index}-*")
      |> JSON.encode!()
      |> put_template(@index)

    Index.hot_swap(Cluster, @index)
  end

  def reindex(ids) do
    Store.transaction(fn ->
      Rule
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, @index, "index"))
      |> Stream.chunk_every(bulk_page_size(@index))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", &1))
      |> Stream.map(&log(&1, @action))
      |> Stream.run()
    end)
  end

  def delete(ids) do
    Enum.map(ids, &Elasticsearch.delete_document(Cluster, &1, @index))
  end

  def migrate do
    unless alias_exists?(@index) do
      if can_migrate?() do
        delete_existing_index("quality_rule")

        Timer.time(
          fn -> reindex(:all) end,
          fn millis, _ -> Logger.info("Created index #{@index} in #{millis}ms") end
        )
      else
        Logger.warn("Another process is migrating")
      end
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
