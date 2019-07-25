defmodule TdDq.Search.IndexWorker do
  @moduledoc """
  GenServer to run reindex task
  """

  use GenServer

  alias TdDq.Search.Indexer

  require Logger

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def reindex(index_name, items) do
    GenServer.cast(TdDq.Search.IndexWorker, {:reindex, index_name, items})
  end

  def partial_reindex(items) do
    GenServer.cast(TdDq.Search.IndexWorker, {:partial_reindex, items})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:reindex, index_name, items}, state) do
    Logger.info("Reindexing. Index name: " <> index_name)

    start_time = DateTime.utc_now()
    Indexer.reindex(index_name, items)
    end_time = DateTime.utc_now()

    Logger.info(
      "Indexed. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:partial_reindex, items}, state) do
    start_time = DateTime.utc_now()
    Indexer.partial_reindex(items)
    end_time = DateTime.utc_now()

    Logger.info(
      "Indexed. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"
    )

    {:noreply, state}
  end
end
