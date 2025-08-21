defmodule TdDd.DataStructures.BulkUpdater do
  @moduledoc """
  Structure notes CSV bulk update GenServer
  """

  use GenServer

  require Logger

  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.DataStructures.FileBulkUpdateEvents

  @shutdown_timeout 2000

  @doc """
  Starts the `GenServer`
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def bulk_csv_update(csv_hash, structures_content_upload, user_id, auto_publish, lang) do
    GenServer.call(
      __MODULE__,
      {:bulk_csv_update, csv_hash, structures_content_upload, user_id, auto_publish, lang},
      60_000
    )
  end

  def timeout do
    :td_dd
    |> Application.get_env(__MODULE__)
    |> Keyword.get(:timeout_seconds)
    |> Kernel.*(1000)
  end

  ## GenServer callbacks
  @impl true
  def init(opts) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, %{tasks: %{}, notify: Keyword.get(opts, :notify)}}
  end

  @impl true
  def handle_call(
        {:bulk_csv_update, csv_hash, structures_content_upload, user_id, auto_publish, lang},
        _from,
        state
      ) do
    %{reply: update_state, state: new_state} =
      csv_hash
      |> pending_update()
      |> launch_task(csv_hash, state, structures_content_upload, user_id, auto_publish, lang)

    {:reply, update_state, new_state}
  end

  def launch_task(
        :not_pending,
        csv_hash,
        state,
        %{filename: filename} = structures_content_upload,
        user_id,
        auto_publish,
        lang
      ) do
    Task.Supervisor.children(TdDd.TaskSupervisor)

    task =
      Task.Supervisor.async_nolink(
        TdDd.TaskSupervisor,
        fn ->
          with {[_ | _] = contents, _errors} <-
                 BulkUpdate.from_csv(structures_content_upload, lang),
               {:ok, %{updates: updates, update_notes: update_notes}} <-
                 BulkUpdate.file_bulk_update(contents, [], user_id, auto_publish: auto_publish),
               [updated_notes, not_updated_notes] <-
                 BulkUpdate.split_succeeded_errors(update_notes) do
            BulkUpdate.make_summary(updates, updated_notes, not_updated_notes)
          else
            error -> error
          end
        end
      )

    Task.Supervisor.children(TdDd.TaskSupervisor)

    task_timer = Process.send_after(self(), {:timeout, task}, timeout())

    FileBulkUpdateEvents.create_event(%{
      user_id: user_id,
      status: "STARTED",
      hash: csv_hash,
      task_reference: ref_to_string(task.ref),
      filename: filename
    })

    %{
      reply: {:just_started, csv_hash, ref_to_string(task.ref)},
      state:
        put_in(
          state.tasks[task.ref],
          %{
            task: task,
            task_timer: task_timer,
            csv_hash: csv_hash,
            filename: filename,
            user_id: user_id,
            auto_publish: auto_publish
          }
        )
    }
  end

  def launch_task(
        {:already_started, _event_pending} = update_state,
        _csv_hash,
        state,
        _structures_content_upload,
        _user_id,
        _auto_publish,
        _lang
      ) do
    %{reply: update_state, state: state}
  end

  def pending_update(csv_hash) do
    case FileBulkUpdateEvents.last_event_by_hash(csv_hash) do
      nil ->
        :not_pending

      %FileBulkUpdateEvent{status: "COMPLETED"} ->
        :not_pending

      %FileBulkUpdateEvent{status: "FAILED"} ->
        :not_pending

      %FileBulkUpdateEvent{status: "TIMED_OUT"} ->
        :not_pending

      %FileBulkUpdateEvent{status: "ALREADY_STARTED"} = event_pending ->
        {:already_started, event_pending}
    end
  end

  def ref_to_string(ref) when is_reference(ref) do
    string_ref =
      ref
      |> :erlang.ref_to_list()
      |> List.to_string()

    Regex.run(~r/<(.*)>/, string_ref)
    |> Enum.at(1)
  end

  def maybe_notify(nil, _msg), do: nil

  def maybe_notify(callback, msg) do
    callback.(:info, msg)
  end

  # If the task succeeds...
  @impl true
  def handle_info({ref, {:error, error}} = msg, %{notify: notify} = state) do
    # The task succeed so we can cancel the monitoring and discard the DOWN message
    Process.demonitor(ref, [:flush])
    {task_info, state} = pop_in(state.tasks[ref])

    Process.cancel_timer(task_info.task_timer)

    create_event(task_info, :DOWN, error)
    maybe_notify(notify, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({ref, summary} = msg, %{notify: notify} = state) when is_reference(ref) do
    # The task succeed so we can cancel the monitoring and discard the DOWN message
    Process.demonitor(ref, [:flush])

    {task_info, state} = pop_in(state.tasks[ref])
    Process.cancel_timer(task_info.task_timer)
    create_event(summary, task_info)
    maybe_notify(notify, msg)
    {:noreply, state}
  end

  # If the task fails...
  @impl true
  def handle_info({:DOWN, ref, _, _pid, reason}, state) when is_reference(ref) do
    {task_info, state} = pop_in(state.tasks[ref])
    create_event(task_info, :DOWN, reason)
    {:noreply, state}
  end

  # This handle function executes when the task has timed out
  @impl true
  def handle_info({:timeout, %{ref: ref} = task}, state) when is_reference(ref) do
    {task_info, state} = pop_in(state.tasks[ref])

    Logger.warning(
      "Task timeout, reference: #{inspect(ref)}}, trying to shut it down in #{@shutdown_timeout}..."
    )

    case Task.shutdown(task, @shutdown_timeout) do
      {:ok, reply} ->
        # Reply received while shutting down
        create_event(task_info, :timeout, reply)

      {:exit, reason} ->
        # Task died
        create_event(task_info, :timeout, reason)

      nil ->
        create_event(task_info, :timeout, "shutdown")
    end

    {:noreply, state}
  end

  def create_event(summary, task_info) do
    %{csv_hash: csv_hash, filename: filename, user_id: user_id, task: %{ref: ref}} = task_info

    FileBulkUpdateEvents.create_event(%{
      response: summary,
      user_id: user_id,
      hash: csv_hash,
      filename: filename,
      status: "COMPLETED",
      task_reference: ref_to_string(ref)
    })
  end

  def create_event(task_info, fail_type, message) do
    %{csv_hash: csv_hash, filename: filename, user_id: user_id, task: %{ref: ref}} = task_info

    FileBulkUpdateEvents.create_event(%{
      user_id: user_id,
      hash: csv_hash,
      filename: filename,
      status: fail_type_to_str(fail_type),
      task_reference: ref_to_string(ref),
      message: "#{fail_type}, #{inspect(message)}"
    })
  end

  defp fail_type_to_str(fail_type) do
    case fail_type do
      :DOWN -> "FAILED"
      :timeout -> "TIMED_OUT"
    end
  end
end
