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

  def reindex(:all) do
    GenServer.cast(TdDq.Search.IndexWorker, {:reindex, :all})
  end

  def reindex(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:reindex, ids})
  end

  def reindex(id) do
    reindex([id])
  end

  def delete(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete, ids})
  end

  def delete(id) do
    delete([id])
  end

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    Logger.info("Reindexing all rules")

    start_time = DateTime.utc_now()
    Indexer.reindex(:rule)
    end_time = DateTime.utc_now()

    Logger.info(
      "Indexed. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_call({:reindex, ids}, _from, state) do
    Logger.info("Reindexing #{Enum.count(ids)} rules")
    start_time = DateTime.utc_now()
    reply = Indexer.reindex(ids, :rule)
    millis = DateTime.utc_now() |> DateTime.diff(start_time, :millisecond)
    Logger.info("Rules indexed in #{millis}ms")

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:delete, ids}, _from, state) do
    Logger.info("Deleting #{Enum.count(ids)} rules")
    start_time = DateTime.utc_now()
    reply = Indexer.delete(ids, :rule)
    millis = DateTime.utc_now() |> DateTime.diff(start_time, :millisecond)
    Logger.info("Rules deleted in #{millis}ms")

    {:reply, reply, state}
  end
end
