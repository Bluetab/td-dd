defmodule TdDd.Loader.LoaderWorker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  use GenServer

  alias TdDd.Loader
  alias TdDd.Repo

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def load(structures, fields, relations, audit, opts \\ []) do
    case Keyword.has_key?(opts, :data_structure) do
      nil ->
        GenServer.cast(__MODULE__, {:load, structures, fields, relations, audit})

      _ ->
        GenServer.call(__MODULE__, {:load, structures, fields, relations, audit, opts})
    end
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:load, structures, fields, relations, audit}, state) do
    Repo.transaction(fn -> do_load(structures, fields, relations, audit) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:load, structures, fields, relations, audit, opts}, _from, state) do
    reply = Repo.transaction(fn -> do_load(structures, fields, relations, audit, opts) end)
    {:reply, reply, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  defp do_load(structures, fields, relations, audit, opts \\ []) do
    Logger.info("Bulk loading data structures")
    {ms, res} = Timer.time(fn -> Loader.load(structures, fields, relations, audit, opts) end)

    case res do
      {:ok, ids} ->
        count = Enum.count(ids)
        Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")
        post_process(ids)

      e ->
        Logger.warn("Bulk load failed after #{ms}ms (#{inspect(e)})")
        Repo.rollback(e)
    end
  end

  defp post_process([]), do: :ok

  defp post_process(ids) do
    @index_worker.reindex(ids)
  end
end
