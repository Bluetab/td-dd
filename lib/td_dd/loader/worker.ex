defmodule TdDd.Loader.Worker.Behaviour do
  @moduledoc "Loader worker behaviour, useful for mocking"

  @type system :: TdDd.Systems.System.t()

  @callback load(system, map, map, keyword) :: :ok
  @callback load(binary, binary, binary, map, keyword) :: :ok
end

defmodule TdDd.Loader.Worker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  @behaviour TdDd.Loader.Worker.Behaviour

  use GenServer

  alias TdCx.Events
  alias TdDd.DataStructures.Ancestry
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.Loader
  alias TdDd.Loader.Reader
  alias TdDd.Profiles.ProfileLoader

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl TdDd.Loader.Worker.Behaviour
  def load(system, %{} = params, audit, opts) do
    GenServer.cast(__MODULE__, {:load, system, params, audit, opts})
  end

  @impl TdDd.Loader.Worker.Behaviour
  def load(structures_file, fields_file, relations_file, audit, opts \\ []) do
    system_id = opts[:system_id]
    domain = opts[:domain]

    case Keyword.has_key?(opts, :external_id) do
      true ->
        timeout = Application.get_env(:td_dd, __MODULE__)[:timeout]

        GenServer.call(
          __MODULE__,
          {:load, structures_file, fields_file, relations_file, system_id, domain, audit, opts},
          timeout
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
      log_request(ref, request)
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
    Logger.warning("Task #{inspect(ref)} failed")
    {:noreply, Map.delete(state, :task)}
  end

  defp log_request(_, :await), do: :ok

  defp log_request(
         ref,
         {:load, structures_file, fields_file, relations_file, system_id, _domain, audit, _opts}
       ) do
    params =
      Enum.reject([structures_file, fields_file, relations_file, system_id, audit], &is_nil/1)

    Logger.info("Started task #{inspect(ref)} #{inspect(params)}")
  end

  defp log_request(ref, {:load, %{id: system_id} = _system, _params, audit, _opts}) do
    params = Enum.reject([system_id, audit], &is_nil/1)
    Logger.info("Started task #{inspect(ref)} #{inspect(params)}")
  end

  defp log_request(ref, {:profiles, profiles}) do
    params =
      case profiles do
        [%{external_id: external_id} | _] -> external_id
        _ -> "no external_ids"
      end

    Logger.info("Started task #{inspect(ref)} #{params}...")
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
        {:ok, %{} = records} ->
          do_load(records, audit, opts)

        {:error, errors} ->
          num_errors = Enum.count(errors)

          maybe_create_event(
            %{
              "message" => "Metadata load failed with #{num_errors} invalid records",
              "type" => "FAILED"
            },
            opts
          )

          {:error, errors}
      end
    end)
  end

  defp start_task(
         {:load, system,
          %{"domain" => domain_external_id, "data_structures" => data_structures} = params, audit,
          opts}
       ) do
    Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn ->
      structures = Reader.enrich_data_structures!(system, domain_external_id, data_structures)

      relations =
        params
        |> Map.get("data_structure_relations", [])
        |> Reader.cast_data_structure_relations!()

      records = %{relations: relations, structures: structures}
      do_load(records, audit, opts)
    end)
  end

  defp start_task({:load, system, %{"op" => _replace_or_merge, "values" => records}, audit, opts}) do
    Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn ->
      records
      |> Reader.read_metadata_records()
      |> do_load_metadata(system, audit, opts)
    end)
  end

  defp do_load(%{} = records, audit, opts) do
    Timer.time(
      fn -> Loader.load(records, audit, opts) end,
      fn ms, res ->
        case res do
          {:ok, %{structure_ids: structure_ids, delete_versions: {_, deleted_ids}}} ->
            count = Enum.count(structure_ids)
            Logger.info("Bulk load process completed in #{ms}ms (#{count} structures upserted)")

            maybe_create_event(
              %{
                "message" =>
                  "Bulk load process completed in #{ms}ms (#{count} structures upserted)",
                "type" => "SUCCEEDED"
              },
              opts
            )

            post_process(structure_ids, deleted_ids, opts)

          e ->
            Logger.warning("Bulk load failed after #{ms}ms (#{inspect(e)})")

            maybe_create_event(
              %{
                "message" => "Bulk load failed after #{ms}ms (#{inspect(e)})",
                "type" => "FAILED"
              },
              opts
            )

            e
        end
      end
    )
  end

  defp do_load_metadata({:error, errors}, _system, _audit, _opts) do
    pos = errors |> Enum.take(3) |> Enum.join(", ")

    case Enum.count(errors) do
      1 -> Logger.warning("Metadata load failed with one invalid record (#{pos})")
      n when n <= 3 -> Logger.warning("Metadata load failed with #{n} invalid records (#{pos})")
      n when n > 3 -> Logger.warning("Metadata load failed with #{n} invalid records (#{pos}...)")
    end
  end

  defp do_load_metadata({:ok, records}, system, audit, opts) do
    Timer.time(
      fn -> Loader.replace_mutable_metadata(records, system, audit, opts) end,
      fn ms, res ->
        op = opts |> Keyword.get(:operation, "replace") |> to_string()

        case res do
          {:ok, %{structure_ids: structure_ids}} ->
            count = Enum.count(structure_ids)
            Logger.info("Bulk #{op} process completed in #{ms}ms (#{count} structures updated)")
            post_process(structure_ids, [], opts)

          {:error, :missing_external_ids, [id | _ids], _} = e ->
            Logger.warning(
              "Bulk #{op} failed after #{ms}ms (missing external_ids including #{id})"
            )

            e

          e ->
            Logger.warning("Bulk #{op} failed after #{ms}ms (#{inspect(e)})")
            e
        end
      end
    )
  end

  defp do_load_profiles(profiles) do
    Logger.info("Bulk loading profiles")

    Timer.time(
      fn -> ProfileLoader.load(profiles) end,
      fn ms, res ->
        case res do
          {:ok, ids} ->
            count = Enum.count(ids)
            Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")

          _ ->
            Logger.warning("Bulk load failed after #{ms}")
        end
      end
    )
  end

  defp post_process([], [], _), do: :ok

  defp post_process(structure_ids, deleted_ids, opts) do
    do_post_process(structure_ids, deleted_ids, opts[:external_id])
  end

  defp do_post_process(structure_ids, deleted_ids, nil) do
    # If any ids have been returned by the bulk load process, these
    # data structures should be reindexed.

    if structure_ids != [], do: Indexer.reindex(structure_ids)
    if deleted_ids != [], do: Indexer.delete(deleted_ids)
  end

  defp do_post_process(structure_ids, deleted_ids, external_id) do
    # As the ancestry of the loaded structure may have changed, also reindex
    # that data structure and it's descendents.
    external_id
    |> Ancestry.get_descendent_ids()
    |> Enum.concat(structure_ids)
    |> Enum.uniq()
    |> do_post_process(deleted_ids, nil)
  end

  defp maybe_create_event(event, opts) do
    case opts[:job_id] do
      nil ->
        :ok

      job_id ->
        attrs = Map.put(event, "job_id", job_id)
        Events.create_event(attrs, opts[:claims])
    end
  end
end
