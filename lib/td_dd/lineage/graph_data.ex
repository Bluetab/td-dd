defmodule TdDd.Lineage.GraphData do
  @moduledoc """
  Graph data server for data lineage analysis.
  """

  use GenServer

  alias Graph.Traversal
  alias TdDd.Lineage.GraphData.Nodes
  alias TdDd.Lineage.GraphData.State
  alias TdDd.Lineage.Units

  require Logger

  defstruct g: %Graph{}, t: %Graph{}, ids: [], excludes: [], source_ids: [], type: nil, hash: nil

  @types %{"CONTAINS" => :contains, "DEPENDS" => :depends}
  @refresh_interval 60_000

  @doc "Starts the GraphData server"
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the current state"
  def state do
    GenServer.call(__MODULE__, :state)
  end

  @doc "Modifies the current state"
  def state(state) do
    GenServer.call(__MODULE__, {:state, state})
  end

  @doc "Returns nodes in the graph"
  def nodes(id \\ nil, opts \\ [], claims) do
    request = {:nodes, id, opts, claims}

    case Application.get_env(:td_dd, TdDd.Lineage)[:nodes_timeout] do
      nil ->
        GenServer.call(__MODULE__, request)

      # milliseconds or :infinity
      nodes_timeout ->
        GenServer.call(__MODULE__, request, nodes_timeout)
    end
  end

  @doc """
  Returns graph degree %{in: x, out: y}
  """
  def degree(external_id) do
    case Process.whereis(__MODULE__) do
      nil -> {:error, :down}
      _ -> GenServer.call(__MODULE__, {:degree, external_id})
    end
  end

  @doc "Returns the lineage graph data for the specified external ids"
  def lineage(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:lineage, external_ids, opts})
  end

  def lineage(external_id, opts), do: lineage([external_id], opts)

  def refresh do
    Process.send_after(Process.whereis(__MODULE__), :refresh, 0)
  end

  @doc "Returns the impact graph data for the specified external ids"
  def impact(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:impact, external_ids, opts})
  end

  def impact(external_id, opts), do: impact([external_id], opts)

  @doc "Returns a sample graph data (the largest of `n` random graphs)"
  def sample(n) do
    GenServer.call(__MODULE__, {:sample, n})
  end

  ## GenServer callbacks

  @impl true
  def init(opts) do
    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :refresh, 2_000)
    end

    state = state_from_opts(opts)

    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    {:ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, result}, state) do
    unless result == :normal do
      Logger.warn("#{inspect(ref)} failed")
    end

    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, Map.delete(state, :loading)}
  end

  @impl true
  def handle_info({:load, ts}, state) do
    Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn -> do_load(ts, state) end)
    {:noreply, Map.put(state, :loading, DateTime.utc_now())}
  end

  @impl true
  def handle_info({_ref, %State{} = state}, %{loading: ts} = _state) do
    ms = DateTime.diff(DateTime.utc_now(), ts, :millisecond)
    Logger.info("Graph data loaded in #{ms}ms")
    {:noreply, Map.delete(state, :loading)}
  end

  @impl true
  def handle_info({_ref, _}, state) do
    {:noreply, Map.delete(state, :loading)}
  end

  @impl true
  def handle_info(:refresh, %{ts: ts} = state) do
    alias TdDd.Lineage.Import

    if Import.busy?() do
      Process.send_after(self(), :refresh, @refresh_interval)
    else
      case Units.last_updated() do
        ^ts ->
          Process.send_after(self(), :refresh, @refresh_interval)

        last_updated ->
          Process.send_after(self(), {:load, last_updated}, 0)
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:degree, external_id}, _from, %{depends: depends} = state) do
    reply =
      if Graph.has_vertex?(depends, external_id) do
        {:ok,
         %{
           in: Graph.in_degree(depends, external_id),
           out: Graph.out_degree(depends, external_id)
         }}
      else
        {:error, :bad_vertex}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:state, opts}, _from, state) do
    state =
      case Application.get_env(:td_dd, :env) == :test do
        true -> state_from_opts(opts)
        _ -> state
      end

    {:reply, state, state}
  end

  @impl true
  def handle_call({:nodes, id, opts, claims}, _from, state) do
    reply = Nodes.query_nodes(id, opts, claims, state)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:sample, n}, _from, state) do
    reply = do_sample(state, n)
    {:reply, reply, state}
  rescue
    e ->
      Logger.error("#{inspect(e)}")
      {:reply, e, state}
  end

  @impl true
  def handle_call({:lineage, external_ids, opts}, _from, state) do
    reply =
      state
      |> do_lineage(external_ids, opts[:excludes], opts[:levels])
      |> subgraph(state, :lineage, opts ++ [reverse: true])
      |> add_source_ids(external_ids)
      |> hash(opts)

    {:reply, reply, state}
  rescue
    e ->
      Logger.error("#{inspect(e)}")
      {:reply, e, state}
  end

  @impl true
  def handle_call({:impact, external_ids, opts}, _from, state) do
    reply =
      state
      |> do_impact(external_ids, opts[:excludes], opts[:levels])
      |> subgraph(state, :impact, opts)
      |> add_source_ids(external_ids)
      |> hash(opts)

    {:reply, reply, state}
  rescue
    e ->
      Logger.error("#{inspect(e)}")
      {:reply, e, state}
  end

  ## Private functions

  defp do_sample(%{contains: contains, depends: depends} = state, n) do
    type = Enum.random([:lineage, :impact])

    {subgraph_fn, opts} =
      case type do
        :lineage -> {&do_lineage(state, &1), reverse: true}
        :impact -> {&do_impact(state, &1), []}
      end

    depends
    |> Graph.vertices()
    |> Enum.take_random(n)
    |> Enum.map(&siblings(&1, contains))
    |> Enum.map(subgraph_fn)
    |> Enum.max_by(fn %{ids: ids} -> Enum.count(ids) end)
    |> subgraph(state, type, opts)
    |> add_source_ids(:sample)
    |> hash(%{})
  end

  defp siblings(v, %Graph{} = contains) do
    contains
    |> Graph.in_neighbours(v)
    |> Enum.flat_map(&Graph.out_neighbours(contains, &1))
    |> Enum.take_random(Enum.random([1, 1, 1, 1, 2, 2, 2, 3, 3, 4]))
  end

  defp subgraph(
         %{ids: external_ids, excludes: excludes},
         %{contains: contains, depends: depends},
         type,
         opts
       ) do
    t =
      contains
      |> Graph.subgraph(external_ids)
      |> add_root()

    g = Graph.subgraph(depends, external_ids, opts)

    ids = Enum.filter(external_ids, &Graph.has_vertex?(depends, &1))

    %__MODULE__{g: g, t: t, ids: ids, excludes: excludes, type: type}
  end

  def add_root(%Graph{} = t) do
    t
    |> Graph.source_vertices()
    |> Enum.reduce(
      Graph.add_vertex(t, :root, %{id: "@@ROOT"}),
      &Graph.add_edge(&2, :root, &1)
    )
  end

  defp do_lineage(state, external_ids, excludes \\ [], levels \\ :all)

  defp do_lineage(state, external_ids, nil, levels),
    do: do_lineage(state, external_ids, [], levels)

  defp do_lineage(state, external_ids, excludes, nil),
    do: do_lineage(state, external_ids, excludes, :all)

  defp do_lineage(%{contains: contains, depends: depends}, external_ids, excludes, levels) do
    excludes =
      case excludes do
        [] -> []
        _ -> do_reaching(excludes, depends, levels)
      end

    external_ids
    |> do_reaching(depends, levels)
    |> filter_excludes(excludes)
    |> reaching(contains)
  end

  defp do_impact(state, external_ids, excludes \\ [], levels \\ :all)
  defp do_impact(state, external_ids, nil, levels), do: do_impact(state, external_ids, [], levels)

  defp do_impact(state, external_ids, excludes, nil),
    do: do_impact(state, external_ids, excludes, :all)

  defp do_impact(%{contains: contains, depends: depends}, external_ids, excludes, levels) do
    excludes =
      case excludes do
        [] -> []
        _ -> do_reachable(excludes, depends, levels)
      end

    external_ids
    |> do_reachable(depends, levels)
    |> filter_excludes(excludes)
    |> reaching(contains)
  end

  defp reaching(%{ids: ids, excludes: excludes}, contains) do
    %{ids: Traversal.reaching(ids, contains), excludes: excludes}
  end

  defp filter_excludes(external_ids, []), do: %{ids: external_ids, excludes: []}

  defp filter_excludes(external_ids, [_ | _] = excludes) do
    excludes
    |> MapSet.new()
    |> do_filter_excludes(MapSet.new(external_ids))
  end

  defp do_filter_excludes(excludes, external_ids) do
    excludes = MapSet.intersection(excludes, external_ids)
    ids = MapSet.difference(external_ids, excludes)

    %{
      ids: MapSet.to_list(ids),
      excludes: MapSet.to_list(excludes)
    }
  end

  defp do_reaching(ids, graph, :all) do
    Traversal.reaching(ids, graph)
  end

  defp do_reaching(ids, graph, levels) do
    Traversal.reaching(ids, graph, levels)
  end

  defp do_reachable(ids, graph, :all) do
    Traversal.reachable(ids, graph)
  end

  defp do_reachable(ids, graph, levels) do
    Traversal.reachable(ids, graph, levels)
  end

  defp data_label(%{label: label, type: type, external_id: external_id} = node) do
    label
    |> Map.put(:class, type)
    |> Map.put(:external_id, external_id)
    |> Map.merge(Map.take(node, [:structure_id]))
  end

  defp do_load(nil = _last_updated, _state), do: :ok

  defp do_load(ts, %State{notify: notify}) do
    Logger.info("Load started (ts=#{DateTime.to_iso8601(ts)})")

    groups = Units.list_nodes(type: "Group")
    Logger.info("Read #{Enum.count(groups)} groups")
    resources = Units.list_nodes(type: "Resource")
    Logger.info("Read #{Enum.count(resources)} resources")

    vertices = Enum.concat(groups, resources)
    id_map = Map.new(vertices, &{&1.id, &1.external_id})

    Logger.info("Mapped #{Enum.count(id_map)} ids")

    contains =
      Enum.reduce(
        vertices,
        Graph.new([], acyclic: true),
        &Graph.add_vertex(&2, &1.external_id, data_label(&1))
      )
    Logger.info("Imported #{Graph.no_vertices(contains)} tree vertices")

    depends =
      Enum.reduce(
        resources,
        Graph.new(),
        &Graph.add_vertex(&2, &1.external_id, data_label(&1))
      )

    Logger.info("Imported #{Graph.no_vertices(depends)} graph vertices")

    contains =
      Units.list_relations(type: "CONTAINS")
      |> Enum.map(&to_edge(&1, id_map))
      |> Enum.uniq_by(&Map.take(&1, [:start, :end]))
      |> Enum.reduce(contains, &add_edge/2)

    Logger.info("Imported #{Graph.no_edges(contains)} tree edges")

    depends =
      Units.list_relations(type: "DEPENDS")
      |> Enum.map(&to_edge(&1, id_map))
      |> Enum.uniq_by(&Map.take(&1, [:start, :end]))
      |> Enum.reduce(depends, &add_edge/2)

    Logger.info("Imported #{Graph.no_edges(depends)} graph edges")

    roots = Graph.source_vertices(contains)

    new_state = %State{contains: contains, depends: depends, roots: roots, ts: ts, notify: notify}
    maybe_notify(notify, {:load_finished, new_state})

    new_state
  end

  def maybe_notify(nil, _msg), do: nil

  def maybe_notify(callback, msg) do
    callback.(:info, msg)
  end

  defp add_edge(%{id: id, start: v1, end: v2, metadata: metadata}, %Graph{} = g) do
    case Graph.add_edge(g, id, v1, v2, metadata: metadata) do
      %Graph{} = g ->
        g

      {:error, :bad_vertex} ->
        Logger.warn("Bad edge #{id}")
        g
    end
  end

  defp to_edge(%{type: type, start_id: start_id, end_id: end_id} = attrs, id_map) do
    attrs
    |> Map.put(:type, Map.get(@types, type))
    |> Map.put(:start, Map.get(id_map, start_id))
    |> Map.put(:end, Map.get(id_map, end_id))
  end

  defp add_source_ids(%__MODULE__{g: g} = graph_data, :sample) do
    source_ids = Graph.source_vertices(g)
    add_source_ids(graph_data, source_ids)
  end

  defp add_source_ids(%__MODULE__{excludes: excludes} = graph_data, external_ids) do
    source_ids =
      case excludes do
        [] ->
          external_ids

        _es ->
          external_ids
          |> MapSet.new()
          |> MapSet.difference(MapSet.new(excludes))
          |> MapSet.to_list()
      end

    %{graph_data | source_ids: source_ids}
  end

  defp hash(%__MODULE__{source_ids: source_ids, ids: _ids, type: type} = graph_data, opts) do
    '''
    Constant hash across lineage loads. Node ids might change for new lineage
    load, so avoid using them.
    '''
    hash =
      opts
      |> deterministic_map
      |> Map.merge(%{source_ids: Enum.sort(source_ids), type: type})
      |> :erlang.phash2()
      |> Integer.to_string()

    %{graph_data | hash: hash}
  end

  defp deterministic_map(opts) do
    defaults = %{excludes: [], levels: :all}
    opts
    |> Map.new
    |> Kernel.then(&Map.merge(defaults, &1))
  end

  def sortable(%{"name" => name}), do: String.downcase(name)

  defp state_from_opts(opts) do
    case Keyword.get(opts, :state) do
      %State{} = s -> s
      _ -> %State{}
    end
  end
end
