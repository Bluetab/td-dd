defmodule TdDd.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias Jason, as: JSON
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Migrations
  alias TdDd.Search.Cluster
  alias TdDd.Search.Mappings
  alias TdDd.Search.Store

  require Logger

  @index :structures
  @action "index"

  def reindex(:all) do
    {:ok, _} =
      Mappings.get_mappings()
      |> Map.put(:index_patterns, "#{@index}-*")
      |> JSON.encode!()
      |> put_template(@index)

    Index.hot_swap(Cluster, @index)
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
    Enum.each(ids, &Elasticsearch.delete_document(Cluster, &1, @index))
  end

  def delete(id), do: delete([id])

  def migrate do
    unless alias_exists?(@index) do
      if Migrations.can_migrate?("TD-1721") do
        case Migrations.soft_delete_obsolete_versions() do
          {0, _} -> Logger.debug("No obsolete versions deleted")
          {count, _} -> Logger.warn("Soft-deleted #{count} obsolete data structure versions")
        end

        case Migrations.soft_delete_orphan_fields() do
          {0, _} -> Logger.debug("No orphan fields deleted")
          {count, _} -> Logger.warn("Soft-deleted #{count} orphan fields")
        end

        delete_existing_index(@index)

        Timer.time(
          fn -> reindex(:all) end,
          fn millis, _ -> Logger.info("Migrated index #{@index} in #{millis}ms") end
        )
      else
        Logger.warn("Another process is migrating")
      end
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
end
