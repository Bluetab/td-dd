defmodule TdDd.Search.IndexWorker do
  @moduledoc """
  GenServer to reindex data dictionary
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdDd.Search.Indexer

  require Logger

  ## Client API

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

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
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
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_cast({:reindex, :all}, state) do
    do_reindex(:all)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reindex, ids}, state) do
    Logger.info("Reindexing #{Enum.count(ids)} data structures")
    {ms, _} = Timer.time(fn -> Indexer.reindex(ids) end)
    Logger.info("Data structures indexed in #{ms}ms")

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
    {ms, _} = Timer.time(fn -> Indexer.reindex(:all) end)
    Logger.info("Data structures indexed in #{ms}ms")
  end

  defp reindex_event?(%{event: "add_template", scope: "dd"}), do: true

  defp reindex_event?(_), do: false
end
