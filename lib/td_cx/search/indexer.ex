defmodule TdCx.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """
  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias Jason, as: JSON
  alias TdCache.Redix
  alias TdCx.Search.Cluster
  alias TdCx.Search.Mappings
  alias TdCx.Search.Store
  alias TdCx.Sources.Jobs.Job

  require Logger

  @index :jobs
  @action "index"

  def reindex(:all) do
    {:ok, _} =
      Mappings.get_mappings()
      |> Map.put(:index_patterns, "#{@index}-*")
      |> JSON.encode!()
      |> put_template(@index)

    Cluster
    |> Index.hot_swap(@index)
    |> log_errors()
  end

  def reindex(ids) do
    Store.transaction(fn ->
      Job
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, @index, "index"))
      |> Stream.chunk_every(bulk_page_size(@index))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", &1))
      |> Stream.map(&log(&1, @action))
      |> Stream.run()
    end)
  end

  def delete(jobs) when is_list(jobs) do
    Enum.each(jobs, &delete/1)
  end

  def delete(job) do
    Elasticsearch.delete_document(Cluster, job, "#{@index}")
  end

  def migrate do
    unless alias_exists?(@index) do
      if can_migrate?() do
        delete_existing_index("jobs")

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
    :td_cx
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
    Redix.command!(["SET", "TdCx.Search.Indexer:LOCK", node(), "NX", "EX", 3600]) == "OK"
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
