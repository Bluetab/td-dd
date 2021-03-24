defmodule TdDd.Loader.Worker.Behaviour do
  @moduledoc "Loader worker behaviour, useful for mocking"

  @callback load(binary, binary, binary, map, keyword) :: :ok
end

defmodule TdDd.Loader.Worker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  @behaviour TdDd.Loader.Worker.Behaviour

  use GenServer

  alias TdDd.DataStructures.Ancestry
  alias TdDd.Loader
  alias TdDd.Loader.Reader
  alias TdDd.ProfilingLoader

  require Logger

  @index_worker Application.compile_env(:td_dd, :index_worker)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl TdDd.Loader.Worker.Behaviour
  def load(structures_file, fields_file, relations_file, audit, opts \\ []) do
    system_id = opts[:system_id]
    domain = opts[:domain]

    case Keyword.has_key?(opts, :external_id) do
      true ->
        GenServer.call(
          __MODULE__,
          {:load, structures_file, fields_file, relations_file, system_id, domain, audit, opts}
        )

      _ ->
        GenServer.cast(
          __MODULE__,
          {:load, structures_file, fields_file, relations_file, system_id, domain, audit, opts}
        )
    end
  end

  def load(profiles) do
    GenServer.cast(__MODULE__, {:profiles, profiles})
  end

  def await(timeout \\ 5000) do
    GenServer.call(__MODULE__, :await, timeout)
  end

  @impl true
  def init(_init_arg) do
    schedule_work(:work, 0)
    state = %{queue: :queue.new()}
    {:ok, state}
  end

  @impl true
  def handle_cast(request, %{queue: queue} = state) do
    queue = :queue.in({request, :none}, queue)
    {:noreply, %{state | queue: queue}}
  end

  @impl true
  def handle_call(request, from, %{queue: queue} = state) do
    queue = :queue.in({request, from}, queue)
    {:noreply, %{state | queue: queue}}
  end

  @impl true
  def handle_info(:work, %{task: _} = state) do
    schedule_work(:work, 100)
    {:noreply, state}
  end

  @impl true
  def handle_info(:work, %{queue: queue} = state) do
    schedule_work(:work, 100)

    with {{:value, {request, from}}, queue} <- :queue.out(queue),
         %Task{ref: ref} = task <- start_task(request) do
      Logger.info("Started task #{inspect(ref)} #{inspect(request)}")
      {:noreply, %{queue: queue, task: task, from: from}}
    else
      _ -> {:noreply, state}
    end
  end

  @impl true
  def handle_info({ref, result}, %{from: from} = state) when is_reference(ref) do
    unless from == :none, do: GenServer.reply(from, result)
    {:noreply, Map.delete(state, :from)}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{task: _} = state) do
    Logger.info("#{inspect(ref)} completed")
    {:noreply, Map.delete(state, :task)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _error}, %{task: _} = state) do
    Logger.warn("Task #{inspect(ref)} failed")
    {:noreply, Map.delete(state, :task)}
  end

  defp schedule_work(action, millis) do
    Process.send_after(self(), action, millis)
  end

  defp start_task({:profiles, profiles}) do
    Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn -> do_load_profiles(profiles) end)
  end

  defp start_task(:await) do
    Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn -> :ok end)
  end

  defp start_task(
         {:load, structures_file, fields_file, relations_file, system_id, domain, audit, opts}
       ) do
    Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn ->
      case Reader.read(structures_file, fields_file, relations_file, domain, system_id) do
        {:ok, %{} = records} -> do_load(records, audit, opts)
        error -> error
      end
    end)
  end

  defp do_load(%{} = records, audit, opts) do
    Timer.time(
      fn -> Loader.load(records, audit, opts) end,
      fn ms, res ->
        case res do
          {:ok, %{structure_ids: structure_ids}} ->
            count = Enum.count(structure_ids)
            Logger.info("Bulk load process completed in #{ms}ms (#{count} structures upserted)")
            post_process(structure_ids, opts)

          e ->
            Logger.warn("Bulk load failed after #{ms}ms (#{inspect(e)})")
            e
        end
      end
    )
  end

  defp do_load_profiles(profiles) do
    Logger.info("Bulk loading profiles")

    Timer.time(
      fn -> ProfilingLoader.load(profiles) end,
      fn ms, res ->
        case res do
          {:ok, ids} ->
            count = Enum.count(ids)
            Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")

          _ ->
            Logger.warn("Bulk load failed after #{ms}")
        end
      end
    )
  end

  defp post_process([], _), do: :ok

  defp post_process(structure_ids, opts) do
    do_post_process(structure_ids, opts[:external_id])
  end

  defp do_post_process(structure_ids, nil) do
    # If any ids have been returned by the bulk load process, these
    # data structures should be reindexed.
    @index_worker.reindex(structure_ids)
  end

  defp do_post_process(structure_ids, external_id) do
    # As the ancestry of the loaded structure may have changed, also reindex
    # that data structure and it's descendents.
    external_id
    |> Ancestry.get_descendent_ids()
    |> Enum.concat(structure_ids)
    |> Enum.uniq()
    |> do_post_process(nil)
  end
end
