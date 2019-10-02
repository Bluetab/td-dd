defmodule TdDq.Search.IndexWorker do
  @moduledoc """
  GenServer to run reindex task
  """

  @behaviour TdCache.EventStream.Consumer

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
    {:ok, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    do_reindex(:all)
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

  defp reindex_event?(%{event: "add_template", scope: "dq"}), do: true

  defp reindex_event?(_), do: false

  defp do_reindex(:all) do
    Logger.info("Reindexing all rules")

    start_time = DateTime.utc_now()
    Indexer.reindex(:rule)
    end_time = DateTime.utc_now()

    Logger.info("Indexed. Elapsed seconds: #{DateTime.diff(end_time, start_time)}")
  end
end
