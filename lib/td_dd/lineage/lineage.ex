defmodule TdDd.Lineage do
  @moduledoc """
  `GenServer` module for data lineage.
  """
  use GenServer

  alias Graph
  alias Graph.Drawing
  alias Graph.Layout
  alias TdDd.CSV.Download
  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.Graphs
  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.LineageEvents

  require Logger

  @shutdown_timeout 2000

  @doc """
  Starts the `GenServer`
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns a lineage graph drawing for the specified `external_ids`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def lineage(external_ids, user_id, opts)

  def lineage(external_ids, user_id, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:lineage, external_ids, user_id, opts}, 60_000)
  end

  def lineage(external_id, user_id, opts) do
    lineage([external_id], user_id, opts)
  end

  @doc """
  Returns an impact graph drawing for the specified `external_ids`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def impact(external_id, user_id, opts)

  def impact(external_ids, user_id, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:impact, external_ids, user_id, opts}, 60_000)
  end

  def impact(external_id, user_id, opts), do: impact([external_id], user_id, opts)

  @doc """
  Returns a csv lineage/impact for the specified `external_id`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def lineage_csv(external_id, opts)

  def lineage_csv(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:lineage_csv, external_ids, opts}, 60_000)
  end

  def lineage_csv(external_id, opts), do: lineage_csv([external_id], opts)

  @doc """
  Returns a csv lineage for the specified `external_id`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def impact_csv(external_id, opts)

  def impact_csv(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:impact_csv, external_ids, opts}, 60_000)
  end

  def impact_csv(external_id, opts), do: impact_csv([external_id], opts)

  @doc """
  Returns a lineage or impact graph drawing for a random sample.
  """
  def sample(user_id) do
    GenServer.call(__MODULE__, {:sample, user_id}, 60_000)
  end

  def test_env_task_await(task_reference, create_event?) do
    GenServer.call(__MODULE__, {:test_env_task_await, task_reference, create_event?})
  end

  ## GenServer callbacks

  @impl true
  def init(_opts) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, %{tasks: %{}}}
  end

  @impl true
  def handle_call({:lineage, external_ids, user_id, opts}, _from, state) do
    graph_data =
      external_ids
      |> GraphData.lineage(opts)

    %{drawing_task: drawing_task, state: state} =
      launch_task(state, graph_data, user_id, opts ++ [type: :lineage])

    {:reply, drawing_task, state}
  end

  @impl true
  def handle_call({:impact, external_ids, user_id, opts}, _from, state) do
    graph_data =
      external_ids
      |> GraphData.impact(opts)

    %{drawing_task: drawing_task, state: state} =
      launch_task(state, graph_data, user_id, opts ++ [type: :impact])

    {:reply, drawing_task, state}
  end

  @impl true
  def handle_call({:lineage_csv, external_ids, opts}, _from, state) do
    lineage = GraphData.lineage(external_ids, opts)
    {contains, depends} = do_csv(lineage, opts ++ [type: :lineage])
    content = Download.linage_to_csv(contains, depends, opts[:header_labels])
    {:reply, content, state}
  end

  @impl true
  def handle_call({:impact_csv, external_ids, opts}, _from, state) do
    impact = GraphData.impact(external_ids, opts)
    {contains, depends} = do_csv(impact, opts ++ [type: :impact])
    content = Download.linage_to_csv(contains, depends, opts[:header_labels])
    {:reply, content, state}
  end

  @impl true
  def handle_call({:sample, user_id}, _from, state) do
    case GraphData.sample(16) do
      %{type: type, g: g} = r ->
        source_ids = Graph.source_vertices(g)

        graph_data =
          r
          |> Map.put(:source_ids, source_ids)
          |> Map.put(:hash, "#{System.unique_integer([:positive])}")

        %{drawing_task: drawing_task, state: state} =
          launch_task(state, graph_data, user_id, type: type)

        {:reply, drawing_task, state}
    end
  end

  @impl true
  def handle_call({:test_env_task_await, task_reference, create_event?}, _from, state) do
    task_to_await = get_in(state, [:tasks, task_reference, :task])
    await_aux(task_to_await, create_event?, state)
    {:reply, task_reference, state}
  end

  # There will be no task_to_await in case it was processed before by handle_info
  defp await_aux(nil = _task_to_await, _create_event?, state) do
    state
  end

  defp await_aux(%Task{ref: ref} = task_to_await, create_event?, state) do
    Task.await(task_to_await)
    {task_info, state} = pop_in(state.tasks[ref])
    if create_event?, do: create_event(%TdDd.Lineage.Graph{}, task_info)
    state
  end

  # This handle function executes when the task has timed out
  def handle_info({:timeout, %{ref: ref} = task}, state) do
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

  # If the task succeeds...
  @impl true
  def handle_info({ref, graph}, state) do
    # The task succeed so we can cancel the monitoring and discard the DOWN message
    Process.demonitor(ref, [:flush])

    {task_info, state} = pop_in(state.tasks[ref])
    Process.cancel_timer(task_info.task_timer)
    create_event(graph, task_info)
    {:noreply, state}
  end

  # If the task fails...
  def handle_info({:DOWN, ref, _, _, reason}, state) do
    {task_info, state} = pop_in(state.tasks[ref])
    create_event(task_info, :DOWN, reason)
    {:noreply, state}
  end

  def create_event(%TdDd.Lineage.Graph{id: graph_id}, task_info) do
    %{hash: hash, user_id: user_id, graph_data: graph_data, task: %{ref: ref}} = task_info

    LineageEvents.create_event(%{
      graph_id: graph_id,
      graph_data: graph_data,
      user_id: user_id,
      graph_hash: hash,
      status: "COMPLETED",
      task_reference: ref_to_string(ref)
    })
  end

  def create_event(task_info, fail_type, message) do
    %{hash: hash, user_id: user_id, graph_data: graph_data, task: %{ref: ref}} = task_info

    LineageEvents.create_event(%{
      graph_data: graph_data,
      user_id: user_id,
      graph_hash: hash,
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

  ## Private functions

  def ref_to_string(ref) when is_reference(ref) do
    string_ref =
      ref
      |> :erlang.ref_to_list()
      |> List.to_string()

    Regex.run(~r/<(.*)>/, string_ref)
    |> Enum.at(1)
  end

  defp find_no_pending_drawing(%{hash: hash} = _graph_data) do
    with :ok <- no_pending_graph(hash),
         %TdDd.Lineage.Graph{} = g <- find_graph_by_hash(hash) do
      {:ok, g}
    end
  end

  def no_pending_graph(hash) do
    case LineageEvents.last_event_by_hash(hash) do
      nil ->
        :ok

      %LineageEvent{status: "COMPLETED"} ->
        :ok

      %LineageEvent{status: "FAILED"} ->
        :ok

      %LineageEvent{status: "TIMED_OUT"} ->
        :ok

      %LineageEvent{status: "ALREADY_STARTED"} = event_pending ->
        {:already_started, event_pending}
    end
  end

  def find_graph_by_hash(hash) do
    case Graphs.find_by_hash(hash) do
      nil ->
        {:not_found, hash}

      g ->
        g
    end
  end

  def timeout do
    Application.get_env(:td_dd, __MODULE__)
    |> Map.Helpers.to_map()
    |> timeout
  end

  def timeout(%{timeout: timeout}), do: timeout
  def timeout(nil), do: 90_000

  def launch_task(state, graph_data, user_id, opts) do
    drawing = find_no_pending_drawing(graph_data)
    launch_task(state, graph_data, drawing, user_id, opts)
  end

  def launch_task(state, graph_data, {:not_found, hash}, user_id, opts) do
    task =
      Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn -> do_drawing(graph_data, opts) end)

    task_timer = Process.send_after(self(), {:timeout, task}, timeout())

    graph_data_string =
      graph_data
      |> Map.get(:source_ids)
      |> Enum.flat_map(fn source_id -> String.split(source_id, "/") |> Enum.take(-1) end)
      |> limit_total_length(255)
      |> Jason.encode!()

    LineageEvents.create_event(%{
      user_id: user_id,
      graph_data: graph_data_string,
      status: "STARTED",
      graph_hash: hash,
      task_reference: task.ref |> ref_to_string
    })

    %{
      drawing_task: {:just_started, hash, task.ref |> ref_to_string},
      state:
        put_in(state.tasks[task.ref], %{
          task: task,
          task_timer: task_timer,
          hash: hash,
          user_id: user_id,
          graph_data: graph_data_string
        })
    }
  end

  def launch_task(state, _graph_data, {:already_started, _event} = drawing, _user_id, _opts) do
    %{drawing_task: drawing, state: state}
  end

  def launch_task(state, _graph_data, {:ok, graph}, _user_id, _opts) do
    %{drawing_task: {:already_calculated, graph}, state: state}
  end

  def do_drawing(%{g: g, t: t, excludes: excludes, source_ids: source_ids, hash: hash}, opts) do
    with %Layout{} = layout <- Layout.layout(g, t, source_ids, opts ++ [excludes: excludes]),
         %Drawing{} = drawing <- Drawing.new(layout, &label_fn/1) do
      Logger.info(
        "Completed type=#{opts[:type]} ids=#{inspect(source_ids)} excludes=#{inspect(excludes)}"
      )

      drawing
      |> add_metadata(edges(g))
      |> Graphs.create(hash)
    end
  end

  defp label_fn(%{structure_id: structure_id} = data) do
    data
    |> Map.delete(:structure_id)
    |> label_fn()
    |> Map.put(:structure_id, structure_id)
  end

  defp label_fn(%{:external_id => id, "name" => name, "type" => type}) do
    %{id: id, name: name, type: type}
  end

  defp label_fn(%{:external_id => id, "name" => name}) do
    %{id: id, name: name}
  end

  defp label_fn(%{id: id}), do: %{id: id}

  defp label_fn(_), do: %{}

  defp add_metadata(%{paths: paths} = drawing, depends) do
    paths
    |> Enum.map(&with_metadata(&1, depends))
    |> (&Map.put(drawing, :paths, &1)).()
  end

  defp with_metadata(path, depends) do
    Enum.find_value(depends, fn edge ->
      add_metadata_to_path(path, edge)
    end)
  end

  defp add_metadata_to_path(path, edge) do
    has_same_vs = Map.take(path, [:v1, :v2]) === Map.take(edge, [:v1, :v2])
    metadata = edge |> Map.get(:label) |> Map.get(:metadata)

    if has_same_vs and not is_nil(metadata) do
      Map.put(path, "metadata", metadata)
    else
      path
    end
  end

  defp do_csv(%{g: g, t: t}, opts) do
    contains = edges(t)
    depends = edges(g)

    {relations(t, contains), relations(g, depends, opts[:type])}
  end

  defp edges(graph) do
    graph
    |> Graph.get_edges()
    |> Enum.reject(fn %{v1: v1} -> v1 == :root end)
  end

  defp relations(graph, edges, type \\ nil)

  defp relations(graph, edges, type) do
    edges
    |> Enum.map(&source_to_target(&1, graph, type))
    |> Enum.reject(fn rel ->
      Map.get(rel[:source], :external_id) == Map.get(rel[:target], :external_id)
    end)
  end

  defp source_to_target(%{v1: v1, v2: v2}, graph, :lineage) do
    source = vertex_attrs(v2, graph)
    target = vertex_attrs(v1, graph)

    [source: source, target: target]
  end

  defp source_to_target(%{v1: v1, v2: v2}, graph, _type) do
    source = vertex_attrs(v1, graph)
    target = vertex_attrs(v2, graph)

    [source: source, target: target]
  end

  defp vertex_attrs(id, graph) do
    label =
      graph
      |> Graph.vertex(id)
      |> Map.get(:label)

    class = Map.get(label, :class)
    external_id = Map.get(label, :external_id)
    name = Map.get(label, "name")

    Map.new()
    |> Map.put(:external_id, external_id)
    |> Map.put(:name, name)
    |> Map.put(:class, class)
  end

  defp limit_total_length(source_ids, limit) do
    {list, _sum} =
      Enum.with_index(source_ids)
      |> Enum.reduce_while(
        {[], 0},
        fn {source_id, index}, {list, sum} ->
          # Json list:
          # Beginning and end bracket
          # For each element:
          #   two quotes, two backslashes for escaping the quote, separaating comma
          if sum + String.length(source_id) + 2 + 5 * (index + 1) <= limit do
            {:cont, {[source_id | list], sum + String.length(source_id)}}
          else
            {:halt, {list, sum}}
          end
        end
      )

    Enum.reverse(list)
  end
end
