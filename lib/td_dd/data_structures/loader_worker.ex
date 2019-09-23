defmodule TdDd.Loader.LoaderWorker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  use GenServer

  alias TdDd.DataStructures.Ancestry
  alias TdDd.Loader
  alias TdDd.ProfilingLoader
  alias TdDd.Repo

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def load(structures, fields, relations, audit, opts \\ []) do
    case Keyword.has_key?(opts, :external_id) do
      true ->
        GenServer.call(__MODULE__, {:load, structures, fields, relations, audit, opts})

      _ ->
        GenServer.cast(__MODULE__, {:load, structures, fields, relations, audit})
    end
  end

  def load(profiles) do
    GenServer.cast(TdDd.Loader.LoaderWorker, {:profiles, profiles})
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:profiles, profiles}, state) do
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
        post_process(ids, opts)

      e ->
        Logger.warn("Bulk load failed after #{ms}ms (#{inspect(e)})")
        Repo.rollback(e)
    end
  end

  defp post_process([], _), do: :ok

  defp post_process(ids, opts) do
    do_post_process(ids, opts[:external_id])
  end

  defp do_post_process(ids, nil) do
    # If any ids have been returned by the bulk load process, these
    # data structures should be reindexed.
    @index_worker.reindex(ids)
  end

  defp do_post_process(ids, external_id) do
    #  As the ancestry of the loaded structure may have changed, also reindex
    # that data structure and it's descendents.
    external_id
    |> Ancestry.get_descendent_ids()
    |> Enum.concat(ids)
    |> Enum.uniq()
    |> do_post_process(nil)
  end
end
