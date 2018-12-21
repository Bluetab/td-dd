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

  def reindex do
    GenServer.cast(TdDd.Search.IndexWorker, {:reindex})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:reindex}, state) do
    Logger.info("Reindexing data structures")
    start_time = DateTime.utc_now()
    Indexer.reindex(:data_structure)
    end_time = DateTime.utc_now()

    Logger.info(
      "Data structures indexed. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"
    )

    {:noreply, state}
  end
end
