defmodule TdCx.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """
  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
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
    |> put_template(alias_name)
    |> case do
      {:ok, _} ->
        Cluster
        |> Index.hot_swap(alias_name)
        |> log_errors()

      error ->
        error
    end
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
      |> Stream.map(&log(&1, @action))
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

    unless alias_exists?(alias_name) do
      if can_reindex?() do
        delete_existing_index(alias_name)

        Timer.time(
          fn -> reindex(:all) end,
          fn millis, _ -> Logger.info("Created index #{alias_name} in #{millis}ms") end
        )
      else
        Logger.warn("Another process is migrating")
      end
    end
  end

  defp put_template(template, name) do
    case Elasticsearch.put(Cluster, "/_template/#{name}", template,
           params: %{"include_type_name" => "false"}
         ) do
      {:ok, res} ->
        {:ok, res}

      {:error, e} ->
        Logger.warn("Error updating template #{name}: #{inspect(e)}")
        {:error, e}
    end
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

  # Ensure only one instance of cx is reindexing by creating a lock in Redis
  defp can_reindex? do
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
