defmodule TdDd.DataStructures.BulkUpdater do
  @moduledoc """
  Structure notes CSV bulk update GenServer
  """

  use GenServer

  require Logger

  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.CsvBulkUpdateEvent
  alias TdDd.DataStructures.CsvBulkUpdateEvents

  @shutdown_timeout 2000

  @doc """
  Starts the `GenServer`
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def bulk_csv_update(csv_hash, structures_content_upload, user_id, auto_publish) do
    GenServer.call(
      __MODULE__,
      {:bulk_csv_update, csv_hash, structures_content_upload, user_id, auto_publish},
      60_000
    )
  end

  def timeout do
    Application.get_env(:td_dd, __MODULE__)
    |> Map.Helpers.to_map()
    |> timeout_seconds
    |> Kernel.*(1000)
  end

  def timeout_seconds(%{timeout_seconds: timeout_seconds}), do: timeout_seconds
  def timeout_seconds(nil), do: 700

  ## GenServer callbacks
  @impl true
  def init(opts) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, %{tasks: %{}, notify: Keyword.get(opts, :notify)}}
  end

  @impl true
  def handle_call(
        {:bulk_csv_update, csv_hash, structures_content_upload, user_id, auto_publish},
        _from,
        state
      ) do
    %{reply: update_state, state: new_state} =
      csv_hash
      ## Obtiene el stuatus
      |> pending_update()
      |> launch_task(csv_hash, state, structures_content_upload, user_id, auto_publish)

    {:reply, update_state, new_state}
  end

  def launch_task(:not_pending, csv_hash, state, structures_content_upload, user_id, auto_publish) do
    Task.Supervisor.children(TdDd.TaskSupervisor)

    task =
      Task.Supervisor.async_nolink(
        TdDd.TaskSupervisor,
        fn ->
          with [_ | _] = contents <-
                 BulkUpdate.from_csv(structures_content_upload)
                 |> IO.inspect(label: "contents inside task"),
               {:ok, %{updates: updates, update_notes: update_notes}} <-
                 BulkUpdate.do_csv_bulk_update(contents, user_id, auto_publish)
                 |> IO.inspect(label: "bulkupdate insede task"),
               [updated_notes, not_updated_notes] <-
                 BulkUpdate.split_succeeded_errors(update_notes)
                 |> IO.inspect(label: "split errors"),
               summary <-
                 make_summary(updates, updated_notes, not_updated_notes)
                 |> IO.inspect(label: "make summary ->") do
            summary
          else
            # {:error, reason} -> reason
            something -> IO.inspect(something, label: "error something ->")
          end

          # contents =
          #   BulkUpdate.from_csv(structures_content_upload)
          #   |> IO.inspect(label: "contents inside task")

          # {:ok, %{updates: updates, update_notes: update_notes}} =
          #   BulkUpdate.do_csv_bulk_update(contents, user_id, auto_publish)
          #   |> IO.inspect(label: "bulkupdate insede task")

          # [updated_notes, not_updated_notes] =
          #   BulkUpdate.split_succeeded_errors(update_notes)
          #   |> IO.inspect(label: "split errors")

          # make_summary(updates, updated_notes, not_updated_notes)
          # |> IO.inspect(label: "make summary ->")
        end
      )

    Task.Supervisor.children(TdDd.TaskSupervisor)

    task_timer = Process.send_after(self(), {:timeout, task}, timeout())

    CsvBulkUpdateEvents.create_event(%{
      user_id: user_id,
      status: "STARTED",
      csv_hash: csv_hash,
      task_reference: task.ref |> ref_to_string,
      filename: structures_content_upload.filename
    })

    %{
      reply: {:just_started, csv_hash, task.ref |> ref_to_string},
      state:
        put_in(
          state.tasks[task.ref],
          %{
            task: task,
            task_timer: task_timer,
            csv_hash: csv_hash,
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
        _auto_publish
      ) do
    ## TD-5481  Debeería de comprobar si el proceso sigue vivo

    %{reply: update_state, state: state}
  end

  def pending_update(csv_hash) do
    case CsvBulkUpdateEvents.last_event_by_hash(csv_hash) do
      nil ->
        :not_pending

      %CsvBulkUpdateEvent{status: "COMPLETED"} ->
        :not_pending

      %CsvBulkUpdateEvent{status: "FAILED"} ->
        :not_pending

      %CsvBulkUpdateEvent{status: "TIMED_OUT"} ->
        :not_pending

      %CsvBulkUpdateEvent{status: "ALREADY_STARTED"} = event_pending ->
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
  def handle_info({:DOWN, ref, _, _pid, reason}, state) when is_reference(ref) do
    {task_info, state} = pop_in(state.tasks[ref])
    create_event(task_info, :DOWN, reason)
    {:noreply, state}
  end

  # This handle function executes when the task has timed out
  def handle_info({:timeout, %{ref: ref} = task}, state) when is_reference(ref) do
    {task_info, state} = pop_in(state.tasks[ref])

    Logger.warn(
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
    %{csv_hash: csv_hash, user_id: user_id, task: %{ref: ref}} = task_info

    CsvBulkUpdateEvents.create_event(%{
      response: summary,
      user_id: user_id,
      csv_hash: csv_hash,
      status: "COMPLETED",
      task_reference: ref_to_string(ref)
    })
  end

  def create_event(task_info, fail_type, message) do
    %{csv_hash: csv_hash, user_id: user_id, task: %{ref: ref}} = task_info

    CsvBulkUpdateEvents.create_event(%{
      user_id: user_id,
      csv_hash: csv_hash,
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

  defp make_summary(updates, updated_notes, not_updated_notes) do
    %{
      ids: Enum.uniq(Map.keys(updates) ++ Map.keys(updated_notes)),
      errors:
        not_updated_notes
        |> Enum.map(fn {_id, {:error, {error, %{row: row, external_id: external_id} = _ds}}} ->
          get_messsage_from_error(error)
          |> Enum.map(fn ms ->
            ms
            |> Map.put(:row, row)
            |> Map.put(:external_id, external_id)
          end)
        end)
        |> List.flatten()
    }
  end

  defp get_messsage_from_error(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {k, v} ->
      case v do
        {_error, nested_errors} ->
          get_message_from_nested_errors(k, nested_errors)

        _ ->
          %{
            field: nil,
            message: "#{k}.default"
          }
      end
    end)
    |> List.flatten()
  end

  defp get_message_from_nested_errors(k, nested_errors) do
    Enum.map(nested_errors, fn {field, {_, [{_, e} | _]}} ->
      %{
        field: field,
        message: "#{k}.#{e}"
      }
    end)
  end
end
