defmodule TdDq.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias TdDd.Search.Cluster
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule
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
    alias_name = Cluster.alias_name(index)

    mappings
    |> Map.put(:index_patterns, "#{alias_name}-*")
    |> Jason.encode!()
    |> put_template(index)
    |> case do
      {:ok, _} ->
        Cluster
        |> Index.hot_swap(alias_name)
        |> log_errors()
    end
  end

  defp do_reindex(schema, index, ids) do
    Store.transaction(fn ->
      schema
      |> Store.stream(ids)
      |> Stream.map(&Bulk.encode!(Cluster, &1, index, "index"))
      |> Stream.chunk_every(Cluster.setting(index, :bulk_page_size))
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

  defp put_template(template, name) do
    Elasticsearch.put(Cluster, "/_template/#{name}", template)
  end

  defp delete(ids, index) do
    alias_name = Cluster.alias_name(index)
    Enum.map(ids, &Elasticsearch.delete_document(Cluster, &1, alias_name))
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
