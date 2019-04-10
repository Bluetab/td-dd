defmodule TdDd.Loader.LoaderWorker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  use GenServer

  alias TdDd.Loader

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def load(structures, fields, relations, audit) do
    GenServer.cast(TdDd.Loader.LoaderWorker, {:load, structures, fields, relations, audit})
  end

  def ping() do
    GenServer.call(TdDd.Loader.LoaderWorker, {:ping})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:load, structures, fields, relations, audit}, state) do
    Logger.info("Bulk loading data structures")
    start_time = DateTime.utc_now()
    Loader.load(structures, fields, relations, audit)
    end_time = DateTime.utc_now()

    Logger.info(
      "Data structures loaded in #{DateTime.diff(end_time, start_time, :millisecond)}ms"
    )

    @index_worker.reindex()
    {:noreply, state}
  end

  @impl true
  def handle_call({:ping}, _from, state) do
    {:reply, :pong, state}
  end
end
