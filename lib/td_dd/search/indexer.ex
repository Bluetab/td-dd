defmodule TdDd.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias TdCache.Redix
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.GrantStructure
  alias TdDd.Search.Cluster
  alias TdDd.Search.Mappings
  alias TdDd.Search.Store
  alias TdDd.Search.StructureEnricher
  alias TdDd.Search.Tasks

  require Logger

  @dsv_index :structures
  @grant_index :grants
  @action "index"

  def reindex(:all) do
    Tasks.log_start(@dsv_index)
    :ok = StructureEnricher.refresh()
    reindex_all(Mappings.get_mappings(), @dsv_index)
  end

  def reindex(ids) when is_list(ids) do
    Tasks.log_start(@dsv_index)
    StructureEnricher.refresh()
    reindex(DataStructureVersion, @dsv_index, ids)
  end

  def reindex(id), do: reindex([id])

  def reindex_grants(:all) do
    Tasks.log_start(@grant_index)
    reindex_all(Mappings.get_grant_mappings(), @grant_index)
  end

  def reindex_grants(ids) when is_list(ids) do
    Tasks.log_start(@grant_index)
    reindex(GrantStructure, @grant_index, ids)
  end

  def reindex_grants(id), do: reindex_grants([id])

  defp reindex_all(mappings, index) do
    Store.vacuum()
    alias_name = Cluster.alias_name(index)

    mappings
    |> Map.put(:index_patterns, "#{alias_name}-*")
    |> Jason.encode!()
    |> put_template(alias_name)
    |> case do
      {:ok, result} ->
        Logger.info(
          "put_template result: #{inspect(result)}\n Starting reindex using hot_swap..."
        )

        Cluster
        |> Index.hot_swap(alias_name)
        |> log_errors()

      error ->
        error
    end

    Tasks.log_end()
  end

  defp reindex(schema, index, ids) when is_list(ids) do
    alias_name = Cluster.alias_name(index)

    Store.transaction(fn ->
      schema
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, alias_name, @action))
      |> Stream.chunk_every(Cluster.setting(index, :bulk_page_size))
      |> Stream.map(&Enum.join(&1, ""))
      |> Stream.map(&Elasticsearch.post(Cluster, "/#{alias_name}/_doc/_bulk", &1))
      |> Stream.map(&log(&1, @action))
      |> Stream.run()
    end)

    Tasks.log_end()
  end

  def delete(ids) when is_list(ids) do
    delete(ids, @dsv_index)
  end

  def delete_grants(ids) when is_list(ids) do
    ids_encoded_array = Jason.encode!(Enum.map(ids, &Integer.to_string(&1)))

    query = """
    {
      "query": {
        "terms": {
          "id": #{ids_encoded_array}
        }
      }
    }
    """

    delete_by_query(query, @grant_index)
  end

  defp delete_by_query(query, index) do
    alias_name = Cluster.alias_name(index)
    Elasticsearch.post(Cluster, "/#{alias_name}/_delete_by_query?conflicts=proceed", query)
  end

  defp delete(ids, index) do
    alias_name = Cluster.alias_name(index)
    Enum.map(ids, &Elasticsearch.delete_document(Cluster, &1, alias_name))
  end

  def migrate do
    if acquire_lock?("TD-2589") do
      Logger.info("Reindexing all data structures...")
      alias_name = Cluster.alias_name(:structures)

      Timer.time(
        fn -> reindex(:all) end,
        fn millis, _ -> Logger.info("Reindexed #{alias_name} in #{millis}ms") end
      )
    end
  end

  def put_template(template, name) do
    Elasticsearch.put(Cluster, "/_template/#{name}", template,
      params: %{"include_type_name" => "false"}
    )
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
  defp log_errors({:error, [_ | _] = exceptions}), do: log_errors(exceptions, length(exceptions))
  defp log_errors({:error, e}), do: log_errors(e, 1)

  defp log_errors(e, 1) do
    {index, message} = info(e)
    Logger.error("Hot swap failed. New index #{index} build finished with error: #{message}")
  end

  defp log_errors(exceptions, count) do
    [first_exception | _] = exceptions
    {index, _message} = info(first_exception)

    Enum.reduce(
      exceptions,
      [],
      fn e, acc ->
        {_index, message} = info(e)

        [
          "#{message}\n",
          acc
        ]
      end
    )
    |> Kernel.then(fn messages ->
      ["Hot swap failed. New index #{index} build finished with #{count} errors:\n" | messages]
    end)
    |> Logger.error()
  end

  defp info(e) do
    if Exception.exception?(e) do
      index = info_index(e)
      {index, "#{info_document_id(e)}#{Exception.message(e)}"}
    else
      "#{inspect(e)}"
    end
  end

  defp info_document_id(%Elasticsearch.Exception{raw: %{"_id" => id}}),
    do: "Data structure ID #{id}: "

  defp info_document_id(_), do: ""

  defp info_index(%Elasticsearch.Exception{raw: %{"_index" => index}}), do: "Index #{index}: "
  defp info_index(_e), do: ""
end
