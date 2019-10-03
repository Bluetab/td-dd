defmodule TdDd.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias Jason, as: JSON
  alias TdDd.DataStructures.Migrations
  alias TdDd.Search.Cluster
  alias TdDd.Search.Mappings
  alias TdDd.Search.Store

  require Logger

  @index "structures"
  @index_config Application.get_env(:td_dd, TdDd.Search.Cluster, :indexes)

  def reindex(:all) do
    template =
      Mappings.get_mappings()
      |> Map.put(:index_patterns, "#{@index}-*")
      |> JSON.encode!()

    {:ok, _} = Elasticsearch.put(Cluster, "/_template/#{@index}", template)

    Index.hot_swap(Cluster, @index)
  end

  def reindex(ids) when is_list(ids) do
    %{bulk_page_size: bulk_page_size} =
      @index_config
      |> Keyword.get(:indexes)
      |> Map.get(:structures)

    ids
    |> Stream.chunk_every(bulk_page_size)
    |> Stream.map(&Store.list(&1))
    |> Stream.map(fn chunk ->
      time(bulk_page_size, fn ->
        bulk =
          chunk
          |> Enum.map(&Bulk.encode!(Cluster, &1, @index, "index"))
          |> Enum.join("")

        Elasticsearch.post(Cluster, "/#{@index}/_doc/_bulk", bulk)
      end)
    end)
    |> Stream.run()
  end

  def reindex(id) do
    reindex([id])
  end

  def delete_all(data_structure_versions) do
    Enum.each(data_structure_versions, fn dsv ->
      Elasticsearch.delete_document(Cluster, dsv, @index)
    end)
  end

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

  defp time(bulk_page_size, fun) do
    Timer.time(
      fun,
      fn millis, _ ->
        case millis do
          0 ->
            Logger.info("Indexing rate :infinity items/s")

          millis ->
            rate = div(1_000 * bulk_page_size, millis)
            Logger.info("Indexing rate #{rate} items/s")
        end
      end
    )
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
end
