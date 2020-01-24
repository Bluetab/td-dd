defmodule TdDd.Lineage.GraphData do
  @moduledoc """
  Graph data server for data lineage analysis.
  """

  use GenServer

  alias Graph.Traversal
  alias TdDd.Neo

  require Logger

  defstruct g: %Graph{}, t: %Graph{}, ids: [], excludes: [], source_ids: [], type: nil

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

  @doc "Reloads graph data from Neo4j"
  def reload do
    send(__MODULE__, :load)
  end

  @doc "Returns the lineage graph data for the specified external ids"
  def lineage(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:lineage, external_ids, opts})
  end

  def lineage(external_id, opts), do: lineage([external_id], opts)

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
  def init(_opts) do
    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :load, 1_000)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:load, state) do
    state =
      Timer.time(
        fn -> do_load() end,
        fn ms, _ -> Logger.info("Graph data loaded in #{ms}ms") end
      )

    Process.send_after(self(), :refresh, @refresh_interval)

    {:noreply, state}
  rescue
    e ->
      Logger.error("#{inspect(e)}")
      Logger.info("Error loading graph data, will try again in 60 seconds")
      Process.send_after(self(), :load, 60_000)
      {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, %{ts: ts} = state) do
    case Neo.store_creation_date() do
      ^ts ->
        Process.send_after(self(), :refresh, @refresh_interval)

      _ ->
        Logger.info("Store creation date changed, scheduling reload")
        Process.send_after(self(), :load, 1_000)
    end

    {:noreply, state}
  rescue
    e ->
      Logger.error("#{inspect(e)}")
      {:noreply, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
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
      |> do_lineage(external_ids, opts[:excludes])
      |> subgraph(state, :lineage, opts ++ [reverse: true])
      |> add_source_ids(external_ids)

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
      |> do_impact(external_ids, opts[:excludes])
      |> subgraph(state, :impact, opts)
      |> add_source_ids(external_ids)

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
      Graph.add_vertex(t, :root, data: %{id: "@@ROOT"}),
      &Graph.add_edge(&2, :root, &1)
    )
  end

  defp do_lineage(state, external_ids, excludes \\ [])
  defp do_lineage(state, external_ids, nil), do: do_lineage(state, external_ids, [])

  defp do_lineage(%{contains: contains, depends: depends}, external_ids, excludes) do
    excludes =
      case excludes do
        [] -> []
        _ -> Traversal.reaching(excludes, depends)
      end

    external_ids
    |> Traversal.reaching(depends)
    |> filter_excludes(excludes)
    |> reaching(contains)
  end

  defp do_impact(state, external_ids, excludes \\ [])
  defp do_impact(state, external_ids, nil), do: do_impact(state, external_ids, [])

  defp do_impact(%{contains: contains, depends: depends}, external_ids, excludes) do
    excludes =
      case excludes do
        [] -> []
        _ -> Traversal.reachable(excludes, depends)
      end

    external_ids
    |> Traversal.reachable(depends)
    |> filter_excludes(excludes)
    |> reaching(contains)
  end

  defp reaching(%{ids: ids, excludes: excludes}, contains) do
    %{ids: Traversal.reaching(ids, contains), excludes: excludes}
  end

  defp reaching(ids, contains), do: reaching(%{ids: ids, excludes: []}, contains)

  defp filter_excludes(external_ids, []), do: %{ids: external_ids, excludes: []}

  defp filter_excludes(external_ids, [_ | _] = excludes) do
    excludes
    |> MapSet.new()
    |> do_filter_excludes(MapSet.new(external_ids))
  end

  defp do_filter_excludes(%MapSet{} = excludes, %MapSet{} = external_ids) do
    excludes = MapSet.intersection(excludes, external_ids)
    ids = MapSet.difference(external_ids, excludes)

    %{
      ids: MapSet.to_list(ids),
      excludes: MapSet.to_list(excludes)
    }
  end

  defp do_load do
    ts = Neo.store_creation_date()

    Logger.info("Data load started, StoreCreationDate=#{ts}...")

    groups = Neo.nodes("Group")
    Logger.info("Read #{Enum.count(groups)} groups from Neo4j...")
    resources = Neo.nodes("Resource")
    Logger.info("Read #{Enum.count(resources)} resources from Neo4j...")

    id_map =
      groups
      |> Enum.concat(resources)
      |> Enum.map(&{&1.id, &1.properties["external_id"]})
      |> Map.new()

    Logger.info("Mapped #{Enum.count(id_map)} ids...")

    contains =
      Enum.reduce(
        groups,
        Graph.new([], acyclic: true),
        &Graph.add_vertex(&2, &1.properties["external_id"], data: &1)
      )

    contains =
      Enum.reduce(
        resources,
        contains,
        &Graph.add_vertex(&2, &1.properties["external_id"], data: &1)
      )

    Logger.info("Imported #{Graph.no_vertices(contains)} tree vertices...")

    depends =
      Enum.reduce(
        resources,
        Graph.new(),
        &Graph.add_vertex(&2, &1.properties["external_id"], data: &1)
      )

    Logger.info("Imported #{Graph.no_vertices(depends)} graph vertices...")

    contains =
      Neo.relations("CONTAINS")
      |> Enum.map(&to_edge(&1, id_map))
      |> Enum.reduce(contains, &add_edge/2)

    Logger.info("Imported #{Graph.no_edges(contains)} tree edges...")

    depends =
      Neo.relations("DEPENDS")
      |> Enum.map(&to_edge(&1, id_map))
      |> Enum.reduce(depends, &add_edge/2)

    Logger.info("Imported #{Graph.no_edges(depends)} graph edges...")

    %{contains: contains, depends: depends, ts: ts}
  end

  defp add_edge(%{id: id, start: v1, end: v2}, %Graph{} = g) do
    case Graph.add_edge(g, id, v1, v2, %{}) do
      %Graph{} = g ->
        g

      {:error, :bad_vertex} ->
        Logger.warn("Bad edge #{id}")
        g
    end
  end

  defp to_edge(%{type: type, start: start_id, end: end_id} = attrs, id_map) do
    attrs
    |> Map.drop([:type])
    |> Map.put(:type, Map.get(@types, type))
    |> Map.put(:start, Map.get(id_map, start_id))
    |> Map.put(:end, Map.get(id_map, end_id))
  end

  defp add_source_ids(%__MODULE__{g: g} = graph_data, :sample) do
    source_ids = Graph.source_vertices(g)
    add_source_ids(graph_data, source_ids)
  end

  defp add_source_ids(%__MODULE__{excludes: excludes} = res, external_ids) do
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

    %{res | source_ids: source_ids}
  end
end
