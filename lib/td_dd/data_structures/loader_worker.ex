defmodule TdDd.Loader.LoaderWorker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  use GenServer

  alias TdDd.Loader
  alias TdDd.ProfilingLoader

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def load(structures, fields, relations, audit) do
    GenServer.cast(TdDd.Loader.LoaderWorker, {:load, structures, fields, relations, audit})
  end

  def load(profiles) do
    GenServer.cast(TdDd.Loader.LoaderWorker, {:load, profiles})
  end

  def ping(timeout \\ 5000) do
    GenServer.call(TdDd.Loader.LoaderWorker, :ping, timeout)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:load, structures, fields, relations, audit}, state) do
    Logger.info("Bulk loading data structures")
    {ms, res} = Timer.time(fn -> Loader.load(structures, fields, relations, audit) end)

    case res do
      {:ok, ids} ->
        count = Enum.count(ids)
        Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")
        post_process(ids)

      _ ->
        Logger.warn("Bulk load failed after #{ms}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:load, profiles}, state) do
    Logger.info("Bulk loading profiles")
    {ms, res} = Timer.time(fn -> ProfilingLoader.load(profiles) end)

    case res do
      {:ok, ids} ->
        count = Enum.count(ids)
        Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")

      _ ->
        Logger.warn("Bulk load failed after #{ms}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  defp post_process([]), do: :ok

  defp post_process(ids) do
    @index_worker.reindex(ids)
  end
end
