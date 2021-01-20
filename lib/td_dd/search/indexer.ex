defmodule TdDd.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias TdCache.Redix
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Search.Cluster
  alias TdDd.Search.Mappings
  alias TdDd.Search.Store

  require Logger

  @index :structures
  @action "index"

  def reindex(:all) do
    Mappings.get_mappings()
    |> Map.put(:index_patterns, "#{@index}-*")
    |> Jason.encode!()
    |> put_template(@index)
    |> case do
      {:ok, _} ->
        Cluster
        |> Index.hot_swap(@index)
        |> log_errors()
    end
  end

  def reindex(ids) when is_list(ids) do
    Store.transaction(fn ->
      DataStructureVersion
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, @index, @action))
      |> Stream.chunk_every(bulk_page_size(@index))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", &1))
      |> Stream.map(&log(&1, @action))
      |> Stream.run()
    end)
  end

  def reindex(id), do: reindex([id])

  def delete(ids) when is_list(ids) do
    Enum.each(ids, &Elasticsearch.delete_document(Cluster, &1, "#{@index}"))
  end

  def delete(id), do: delete([id])

  def migrate do
    if acquire_lock?("TD-2589") do
      Logger.info("Reindexing all data structures...")

      Timer.time(
        fn -> reindex(:all) end,
        fn millis, _ -> Logger.info("Reindexed #{@index} in #{millis}ms") end
      )
    end
  end

  defp put_template(template, name) do
    Elasticsearch.put(Cluster, "/_template/#{name}", template)
  end

  defp bulk_page_size(index) do
    :td_dd
    |> Application.get_env(Cluster)
    |> Keyword.get(:indexes)
    |> Map.get(index)
    |> Map.get(:bulk_page_size)
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

  # Ensure only one instance of dd is reindexing by creating a lock in Redis
  defp acquire_lock?(id) do
    Redix.command!(["SET", "TdDd.DataStructures.Migrations:#{id}", node(), "NX"]) == "OK"
  end

  defp log_errors(:ok), do: :ok
  defp log_errors({:error, [e | _] = es}), do: log_errors(e, length(es))
  defp log_errors({:error, e}), do: log_errors(e, 1)

  defp log_errors(e, 1) do
    message = message(e)
    Logger.warn("Reindexing finished with error: #{message}")
  end

  defp log_errors(e, count) do
    message = message(e)
    Logger.warn("Reindexing finished with #{count} errors including: #{message}")
  end

  defp message(e) do
    if Exception.exception?(e) do
      Exception.message(e)
    else
      "#{inspect(e)}"
    end
  end
end
