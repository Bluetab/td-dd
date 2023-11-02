defmodule TdDd.Search.Tasks do
  @moduledoc """
  GenServer to storing Indexing stats.
  """

  use GenServer

  @impl true
  def init(stack) do
    {:ok, stack}
  end

  def start_link(_),
    do:
      GenServer.start_link(
        __MODULE__,
        {:ets.new(:td_dd_tasks, [:public]), :ets.new(:td_dd_keys, [:public])},
        name: __MODULE__
      )

  def log_start(index), do: log({:start, index})

  def log_start_stream(count), do: log({:start_stream, count})

  def log_progress(chunk_size), do: log({:progress, chunk_size})

  def log_end, do: log(:end)

  def log_start(pid, index), do: log(pid, {:start, index})

  def log_start_stream(pid, count), do: log(pid, {:start_stream, count})

  def log_progress(pid, chunk_size), do: log(pid, {:progress, chunk_size})

  def log_end(pid), do: log(pid, :end)

  def log(message) do
    log(self(), message)
  end

  def log(pid, message) do
    GenServer.cast(
      __MODULE__,
      {:push, {pid, DateTime.utc_now(), :erlang.memory(:total)}, message}
    )
  end

  def ets_table do
    GenServer.call(__MODULE__, :ets_table)
  end

  defp record_from_table(tasks, key), do: record_value(:ets.lookup(tasks, key))

  defp pid_key(keys, pid), do: record_value(:ets.lookup(keys, pid))

  defp record_value([{_, record}]), do: record
  defp record_value(_), do: %{}

  defp put_current_stats(%{memory_trace: memory_trace} = record, ts, memory),
    do:
      record
      |> Map.put(:memory_trace, memory_trace ++ [{ts, memory}])
      |> Map.put(:last_message_at, ts)

  defp put_current_stats(record, ts, memory),
    do:
      record
      |> Map.put(:memory_trace, [{ts, memory}])
      |> Map.put(:last_message_at, ts)

  defp update_processed(%{processed: processed} = record, chunk_size),
    do: Map.put(record, :processed, processed + chunk_size)

  defp update_processed(_, _), do: nil

  defp put_status(%{processed: value, count: value} = record),
    do: Map.put(record, :status, :indexing)

  defp put_status(record) when is_map(record), do: Map.put(record, :status, :processing)
  defp put_status(_), do: nil

  defp put_status(record, status) when is_map(record), do: Map.put(record, :status, status)
  defp put_status(_, _), do: nil

  defp put_elapsed(%{id: id} = record),
    do: Map.put(record, :elapsed, :os.system_time(:millisecond) - id)

  defp put_elapsed(_), do: nil

  defp put_count(record, count, processed) when is_map(record) do
    record
    |> Map.put(:count, count)
    |> Map.put(:processed, processed)
  end

  defp put_count(_, _, _), do: nil

  defp insert_record(record, tasks, key) when is_map(record),
    do: :ets.insert(tasks, {key, record})

  defp insert_record(_, _, _), do: nil

  @impl true
  def handle_cast({:push, {pid, ts, memory}, {:start, index}}, {tasks, keys}) do
    id = :os.system_time(:millisecond)

    :ets.insert(
      tasks,
      {id,
       %{
         index: index,
         status: :started,
         started_at: ts,
         id: id,
         elapsed: 0
       }
       |> put_current_stats(ts, memory)}
    )

    :ets.insert(keys, {pid, id})

    {:noreply, {tasks, keys}}
  end

  @impl true
  def handle_cast({:push, {pid, ts, memory}, {:start_stream, count}}, {tasks, keys}) do
    key = pid_key(keys, pid)

    tasks
    |> record_from_table(key)
    |> put_current_stats(ts, memory)
    |> put_elapsed()
    |> put_status(:started_stream)
    |> put_count(count, 0)
    |> insert_record(tasks, key)

    {:noreply, {tasks, keys}}
  end

  @impl true
  def handle_cast({:push, {pid, ts, memory}, {:progress, chunk_size}}, {tasks, keys}) do
    key = pid_key(keys, pid)

    tasks
    |> record_from_table(key)
    |> put_current_stats(ts, memory)
    |> put_elapsed()
    |> update_processed(chunk_size)
    |> put_status()
    |> insert_record(tasks, key)

    {:noreply, {tasks, keys}}
  end

  @impl true
  def handle_cast({:push, {pid, ts, memory}, :end}, {tasks, keys}) do
    key = pid_key(keys, pid)

    tasks
    |> record_from_table(key)
    |> put_current_stats(ts, memory)
    |> put_elapsed()
    |> put_status(:done)
    |> insert_record(tasks, key)

    {:noreply, {tasks, keys}}
  end

  @impl true
  def handle_call(:ets_table, _from, {tasks, keys}) do
    {:reply, tasks, {tasks, keys}}
  end

  @impl true
  def terminate(reason, {ets_table, _}) do
    reason
    |> inspect()
    |> IO.puts()

    ets_table
    |> :ets.tab2list()
    |> IO.puts()
  end
end
