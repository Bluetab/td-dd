defmodule TdDd.Search.IndexWorker do
  @moduledoc """
  GenServer for data dictionary bulk indexing.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdDd.Search.Indexer

  require Logger

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def reindex(:all) do
    GenServer.cast(__MODULE__, {:reindex, :all})
  end

  def reindex([]), do: :ok

  def reindex(data_structure_ids) do
    GenServer.cast(__MODULE__, {:reindex, data_structure_ids})
  end

  def reindex_grants(:all) do
    GenServer.cast(__MODULE__, {:reindex_grants, :all})
  end

  def reindex_grants(grant_ids) when is_list(grant_ids) do
    GenServer.cast(__MODULE__, {:reindex_grants, grant_ids})
  end

  def reindex_grants(grant_id) do
    reindex_grants([grant_id])
  end

  def delete(data_structure_version_ids) do
    GenServer.cast(__MODULE__, {:delete, data_structure_version_ids})
  end

  def delete_grants(grant_ids) when is_list(grant_ids) do
    GenServer.cast(__MODULE__, {:delete_grants, grant_ids})
  end

  def delete_grants(grant_id) do
    delete_grants([grant_id])
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.cast(__MODULE__, {:consume, events})
  end

  ## GenServer Callbacks

  @impl true
  def init(_init_arg) do
    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :migrate, 0)
    end

    Logger.info("started")

    {:ok, :no_state}
  end

  @impl GenServer
  def handle_info(:migrate, state) do
    Indexer.migrate()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete, data_structure_ids}, state) do
    Timer.time(
      fn -> Indexer.delete(data_structure_ids) end,
      fn ms, _ ->
        Logger.info("Deleted #{Enum.count(data_structure_ids)} documents in #{ms}ms")
      end
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_grants, grant_ids}, state) do
    Timer.time(
      fn -> Indexer.delete_grants(grant_ids) end,
      fn ms, _ ->
        Logger.info("Deleted #{Enum.count(grant_ids)} documents in #{ms}ms")
      end
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    do_reindex(:all)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, data_structure_ids}, state) do
    do_reindex(data_structure_ids)
    {:noreply, state}
  end

  def handle_cast({:reindex_grants, :all}, state) do
    do_reindex_grants(:all)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex_grants, grant_ids}, state) do
    do_reindex_grants(grant_ids)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:consume, events}, state) do
    case Enum.any?(events, &reindex_event?/1) do
      true -> do_reindex(:all)
      _ -> :ok
    end

    {:noreply, state}
  end

  defp do_reindex(:all) do
    Logger.info("Reindexing all data structures")

    Timer.time(
      fn -> Indexer.reindex(:all) end,
      fn ms, _ -> Logger.info("Reindexed all data structures in #{ms}ms") end
    )
  end

  defp do_reindex(data_structure_ids) when is_list(data_structure_ids) do
    count = Enum.count(data_structure_ids)
    Logger.info("Reindexing #{count} data structures")

    Timer.time(
      fn -> Indexer.reindex(data_structure_ids) end,
      fn ms, _ -> Logger.info("Reindexed #{count} data structures in #{ms}ms") end
    )
  end

  defp do_reindex(data_structure_id), do: do_reindex([data_structure_id])

  defp reindex_event?(%{event: "template_updated", scope: "dd"}), do: true

  defp reindex_event?(_), do: false

  defp do_reindex_grants(:all) do
    Logger.info("Reindexing all grants")

    Timer.time(
      fn -> Indexer.reindex_grants(:all) end,
      fn ms, _ -> Logger.info("Reindexed all grants in #{ms}ms") end
    )
  end

  defp do_reindex_grants([]), do: :ok

  defp do_reindex_grants(grant_ids) when is_list(grant_ids) do
    count = Enum.count(grant_ids)
    Logger.info("Reindexing #{count} grants")

    Timer.time(
      fn -> Indexer.reindex_grants(grant_ids) end,
      fn ms, _ -> Logger.info("Reindexed #{count} grants in #{ms}ms") end
    )
  end

end
