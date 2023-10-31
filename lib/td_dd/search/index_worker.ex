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

  def reindex_grants(ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:reindex_grants, ids})
  end

  def reindex_grants(id) do
    reindex_grants([id])
  end

  def reindex_grant_requests(:all) do
    GenServer.cast(__MODULE__, {:reindex_grant_requests, :all})
  end

  def reindex_grant_requests(ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:reindex_grant_requests, ids})
  end

  def reindex_grant_requests(id), do: reindex_grant_requests([id])

  def call_reindex_grant_requests(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:reindex_grant_requests, ids})
  end

  def delete(data_structure_version_ids) do
    GenServer.cast(__MODULE__, {:delete, data_structure_version_ids})
  end

  def delete_grants([]), do: :ok

  def delete_grants(ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:delete_grants, ids})
  end

  def delete_grants(id), do: delete_grants([id])

  def delete_grant_requests([]), do: :ok

  def delete_grant_requests(ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:delete_grant_requests, ids})
  end

  def delete_grant_requests(id), do: delete_grant_requests([id])

  def quiesce(timeout \\ 5_000) do
    GenServer.call(__MODULE__, :quiesce, timeout)
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
  def handle_cast({:delete_grants, ids}, state) do
    Timer.time(
      fn -> Indexer.delete_grants(ids) end,
      fn ms, value ->
        case value do
          {:ok, %{"deleted" => deleted}} ->
            Logger.info("Deleted #{deleted} grant documents in #{ms}ms")

          {:error, %Elasticsearch.Exception{message: message}} ->
            Logger.info("Failed to delete grant documents (#{ms}ms): #{message}")
        end
      end
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_grant_requests, ids}, state) do
    Timer.time(
      fn -> Indexer.delete_grant_requests(ids) end,
      fn ms, value ->
        case value do
          {:ok, %{"deleted" => deleted}} ->
            Logger.info("Deleted #{deleted} grant request documents in #{ms}ms")

          {:error, %Elasticsearch.Exception{message: message}} ->
            Logger.info("Failed to delete grant request documents (#{ms}ms): #{message}")
        end
      end
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    do_reindex_structures(:all)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, ids}, state) do
    do_reindex_structures(ids)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex_grants, :all}, state) do
    do_reindex_grants(:all)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex_grants, ids}, state) do
    do_reindex_grants(ids)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex_grant_requests, :all}, state) do
    do_reindex_grant_requests(:all)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex_grant_requests, ids}, state) do
    do_reindex_grant_requests(ids)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:consume, events}, state) do
    case Enum.any?(events, &reindex_event?/1) do
      true -> do_reindex_structures(:all)
      _ -> :ok
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:quiesce, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:reindex_grant_requests, ids}, _from, state) do
    do_reindex_grant_requests(ids)
    {:reply, :ok, state}
  end

  defp do_reindex_structures(:all) do
    Logger.info("Reindexing all data structures")

    Timer.time(
      fn -> Indexer.reindex(:all) end,
      fn ms, _ -> Logger.info("Reindexed all data structures in #{ms}ms") end
    )
  end

  defp do_reindex_structures(data_structure_ids) when is_list(data_structure_ids) do
    count = Enum.count(data_structure_ids)
    Logger.info("Reindexing #{count} data structures")

    Timer.time(
      fn -> Indexer.reindex(data_structure_ids) end,
      fn ms, _ -> Logger.info("Reindexed #{count} data structures in #{ms}ms") end
    )
  end

  defp do_reindex_structures(data_structure_id), do: do_reindex_structures([data_structure_id])

  defp reindex_event?(%{event: "template_updated", scope: "dd"}), do: true

  defp reindex_event?(_), do: false

  defp do_reindex_grants(:all) do
    Logger.info("Reindexing all grants")

    Timer.time(
      fn -> Indexer.reindex_grants(:all) end,
      fn ms, _ -> Logger.info("Reindexed all grants in #{ms}ms") end
    )
  end

  defp do_reindex_grants(ids) when is_list(ids) do
    count = Enum.count(ids)
    Logger.info("Reindexing #{count} grants")

    Timer.time(
      fn -> Indexer.reindex_grants(ids) end,
      fn ms, _ -> Logger.info("Reindexed #{count} grants in #{ms}ms") end
    )
  end

  defp do_reindex_grant_requests(:all) do
    Logger.info("Reindexing all grant requests")

    Timer.time(
      fn -> Indexer.reindex_grant_requests(:all) end,
      fn ms, _ -> Logger.info("Reindexed all grant requests in #{ms}ms") end
    )
  end

  defp do_reindex_grant_requests(ids) when is_list(ids) do
    count = Enum.count(ids)
    Logger.info("Reindexing #{count} grant requests")

    Timer.time(
      fn -> Indexer.reindex_grant_requests(ids) end,
      fn ms, _ -> Logger.info("Reindexed #{count} grant requests in #{ms}ms") end
    )
  end
end
