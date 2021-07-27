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
  def lineage(external_ids, opts)

  def lineage(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:lineage, external_ids, opts}, 60_000)
  end

  def lineage(external_id, opts), do: lineage([external_id], opts)

  @doc """
  Returns an impact graph drawing for the specified `external_ids`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def impact(external_id, opts)

  def impact(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:impact, external_ids, opts}, 60_000)
  end

  def impact(external_id, opts), do: impact([external_id], opts)

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
  def sample do
    GenServer.call(__MODULE__, :sample, 60_000)
  end

  ## GenServer callbacks

  @impl true
  def init(_opts) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:lineage, external_ids, opts}, _from, state) do
    drawing =
      external_ids
      |> GraphData.lineage(opts)
      |> drawing(opts ++ [type: :lineage])

    {:reply, drawing, state}
  end

  @impl true
  def handle_call({:impact, external_ids, opts}, _from, state) do
    drawing =
      external_ids
      |> GraphData.impact(opts)
      |> drawing(opts ++ [type: :impact])

    {:reply, drawing, state}
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
  def handle_call(:sample, _from, state) do
    case GraphData.sample(16) do
      %{type: type, g: g} = r ->
        source_ids = Graph.source_vertices(g)

        drawing =
          r
          |> Map.put(:source_ids, source_ids)
          |> Map.put(:hash, "#{System.unique_integer([:positive])}")
          |> drawing(type: type)

        {:reply, drawing, state}
    end
  end

  ## Private functions

  defp drawing(%{hash: hash} = graph_data, opts) do
    case Graphs.find_by_hash(hash) do
      nil -> do_drawing(graph_data, opts)
      g -> g
    end
  end

  defp do_drawing(%{g: g, t: t, excludes: excludes, source_ids: source_ids, hash: hash}, opts) do
    with %Layout{} = layout <- Layout.layout(g, t, source_ids, opts ++ [excludes: excludes]),
         %Drawing{} = drawing <- Drawing.new(layout, &label_fn/1) do
      "Completed type=#{opts[:type]} ids=#{inspect(source_ids)} excludes=#{inspect(excludes)}"
      |> Logger.info()

      Graphs.create(drawing, hash)
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
