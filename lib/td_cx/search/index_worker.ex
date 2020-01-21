defmodule TdCx.Search.IndexWorker do
  @moduledoc """
  GenServer to reindex jobs
  """
  use GenServer

  # TODO
  alias TdCx.Search.Indexer

  require Logger

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def reindex(:all) do
    GenServer.cast(__MODULE__, {:reindex, :all})
  end

  def reindex(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:reindex, ids}, 30_000)
  end

  def reindex(id) do
    reindex([id])
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_cx, :env) == :test do
      Process.send_after(self(), :migrate, 0)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:migrate, state) do
    Indexer.migrate()
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:reindex, ids}, _from, state) do
    reply = do_reindex(ids)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_cast({:reindex, :all}, state) do
    do_reindex(:all)

    {:noreply, state}
  end

  ## Private functions

  defp do_reindex([]), do: :ok

  defp do_reindex(:all) do
    Logger.info("Reindexing all jobs")

    Timer.time(
      fn -> Indexer.reindex(:all) end,
      fn ms, _ -> Logger.info("Reindexed all jobs in #{ms}ms") end
    )
  end

  defp do_reindex(ids) when is_list(ids) do
    count = Enum.count(ids)

    Timer.time(
      fn -> Indexer.reindex(ids) end,
      fn ms, _ -> Logger.info("Reindexed #{count} jobs in #{ms}ms") end
    )
  end
end
