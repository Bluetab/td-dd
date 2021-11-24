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
  alias TdDd.Lineage.LineageEvents

  require Logger

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

  def task_await(task_reference, create_event?) do
    GenServer.call(__MODULE__, {:task_await, task_reference, create_event?})
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
  def handle_call({:task_await, task_reference, create_event?}, _from, state) do
    task_to_await = get_in(state, [:tasks, task_reference, :task])
    await_aux(task_to_await, create_event?, state)
    {:reply, task_reference, state}
  end

  # There will be no task_to_await in case it was processed before by handle_info
  defp await_aux(nil = _task_to_await, _create_event?, state)  do
    state
  end

  defp await_aux(%Task{ref: ref} = task_to_await, create_event?, state) do
    Task.await(task_to_await)
    {task_info, state} = pop_in(state.tasks[ref])
    if create_event?, do: create_event(task_info)
    state
  end

  # If the task succeeds...
  @impl true
  def handle_info({ref, _result}, state) do
    # The task succeed so we can cancel the monitoring and discard the DOWN message
    Process.demonitor(ref, [:flush])

    {task_info, state} = pop_in(state.tasks[ref])
    create_event(task_info)
    {:noreply, state}
  end

  # If the task fails...
  def handle_info({:DOWN, ref, _, _, reason}, state) do
    {%{hash: hash, user_id: user_id, graph_data: graph_data}, state} = pop_in(state.tasks[ref])

    LineageEvents.create_event(%{
      graph_data: graph_data,
      user_id: user_id,
      graph_hash: hash,
      status: "FAILED",
      task_reference: ref |> ref_to_string,
      message: "#{inspect(reason)}"
    })

    {:noreply, state}
  end

  def create_event(task_info) do
    %{hash: hash, user_id: user_id, graph_data: graph_data, task: %{ref: ref}} = task_info

    LineageEvents.create_event(%{
      graph_data: graph_data,
      user_id: user_id,
      graph_hash: hash,
      status: "COMPLETED",
      task_reference: ref |> ref_to_string
    })
  end

  ## Private functions

  def ref_to_string(ref) when is_reference(ref) do
    ref
    |> :erlang.ref_to_list()
    |> List.to_string()
    |> (fn string_ref ->
      Regex.run(~r/<(.*)>/, string_ref)
    end).()
    |> Enum.at(1)
  end

  defp find_no_pending_drawing(%{hash: hash} = _graph_data) do
    with :ok <- no_pending_graph(hash),
         %TdDd.Lineage.Graph{} = g <- find_graph_by_hash(hash) do
      {:ok, g}
    else
      situation ->
        situation
    end
  end

  def no_pending_graph(hash) do
    case LineageEvents.pending_by_hash(hash) do
      nil -> :ok
      %{} = pending -> {:already_started, pending}
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

  def launch_task(state, graph_data, user_id, opts) do
    drawing = find_no_pending_drawing(graph_data)
    launch_task(state, graph_data, drawing, user_id, opts)
  end

  def launch_task(state, graph_data, {:not_found, hash}, user_id, opts) do
    task =
      Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn -> do_drawing(graph_data, opts) end)

    Task.Supervisor.children(TdDd.TaskSupervisor)
    graph_data_string = GraphData.ids_to_string(graph_data)

    LineageEvents.create_event(%{
      user_id: user_id,
      graph_data: graph_data_string,
      status: "STARTED",
      graph_hash: hash,
      task_reference: task.ref |> ref_to_string
    })

    %{
      drawing_task: {:just_started, hash, task.ref |> ref_to_string},
      state: put_in(state.tasks[task.ref], %{task: task, hash: hash, user_id: user_id, graph_data: graph_data_string})
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
      "Completed type=#{opts[:type]} ids=#{inspect(source_ids)} excludes=#{inspect(excludes)}"
      |> Logger.info()

      graph = Graphs.create(drawing, hash)
      graph
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
end
