defmodule TdDd.Tasks.ReplaceIndex do
  @moduledoc """
  A startup task to check for the existence of expected indexes in
  Elasticsearch, and to create them if they don't exist. Additionally,
  the task will ensure that any data structure versions which have been
  replaced by a newer version will have the deleted_at property set.
  """

  use Task

  import Ecto.Query

  alias TdCache.Redix
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo
  alias TdDd.Search.Cluster
  alias TdDd.Search.IndexWorker

  require Logger

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    case soft_delete_obsolete_versions() do
      {0, _} -> Logger.debug("No obsolete versions deleted")
      {count, _} -> Logger.debug("Soft-deleted #{count} obsolete data structure versions")
    end

    unless alias_exists?("structures") do
      delete_existing_index("structures")

      if aquire_lock?() do
        IndexWorker.reindex(:all)
      else
        Logger.warn("Another process is reindexing")
      end
    end
  end

  defp soft_delete_obsolete_versions(ts \\ DateTime.utc_now()) do
    Repo.update_all(
      from(dsv in DataStructureVersion,
        where: is_nil(dsv.deleted_at),
        join: ds in assoc(dsv, :data_structure),
        join: newer in assoc(ds, :versions),
        where: is_nil(newer.deleted_at),
        where: newer.version > dsv.version,
        update: [set: [deleted_at: ^ts]],
        select: dsv.id
      ),
      []
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

  defp aquire_lock? do
    case Redix.command!(["SET", "TdDd.Tasks.ReplaceIndex:LOCK", "LOCKED", "NX", "EX", 3600]) do
      "OK" -> true
      _ -> false
    end
  end
end
