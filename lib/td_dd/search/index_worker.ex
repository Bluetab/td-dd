defmodule TdDd.Search.IndexWorker do
  @moduledoc """
  GenServer to reindex data dictionary
  """

  use GenServer

  alias TdDd.Search.Indexer

  require Logger

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def reindex(:all) do
    GenServer.cast(__MODULE__, {:reindex, :all})
  end

  def reindex([]), do: :ok

  def reindex(ids) do
    GenServer.cast(__MODULE__, {:reindex, ids})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    Logger.info("Reindexing all data structures")
    {ms, _} = Timer.time(fn -> Indexer.reindex(:all) end)
    Logger.info("Data structures indexed in #{ms}ms")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, ids}, state) do
    Logger.info("Reindexing #{Enum.count(ids)} data structures")
    {ms, _} = Timer.time(fn -> Indexer.reindex(ids) end)
    Logger.info("Data structures indexed in #{ms}ms")

    {:noreply, state}
  end
end
