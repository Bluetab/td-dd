defmodule TdDd.Search.IndexWorker do
  @moduledoc """
  GenServer to reindex data dictionary
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

  def delete(data_structure_version_ids) do
    GenServer.cast(__MODULE__, {:delete, data_structure_version_ids})
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.cast(__MODULE__, {:consume, events})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :migrate, 0)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:migrate, state) do
    Indexer.migrate()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete, data_structure_version_ids}, state) do
    Timer.time(
      fn -> Indexer.delete(data_structure_version_ids) end,
      fn ms, _ ->
        Logger.info("Deleted #{Enum.count(data_structure_version_ids)} documents in #{ms}ms")
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
end
