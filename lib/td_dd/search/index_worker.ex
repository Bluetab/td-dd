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
    GenServer.cast(TdDd.Search.IndexWorker, {:reindex, :all})
  end

  def reindex(structures) do
    GenServer.cast(TdDd.Search.IndexWorker, {:reindex, structures})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    Logger.info("Reindexing all data structures")
    start_time = DateTime.utc_now()
    Indexer.reindex(:all)
    millis = DateTime.utc_now() |> DateTime.diff(start_time, :millisecond)
    Logger.info("Data structures indexed in #{millis}ms")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, structures}, state) do
    Logger.info("Reindexing #{Enum.count(structures)} data structures")
    start_time = DateTime.utc_now()
    Indexer.reindex(structures)
    millis = DateTime.utc_now() |> DateTime.diff(start_time, :millisecond)
    Logger.info("Data structures indexed in #{millis}ms")

    {:noreply, state}
  end
end
