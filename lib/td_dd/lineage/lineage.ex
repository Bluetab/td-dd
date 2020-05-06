defmodule TdDd.Lineage do
  @moduledoc """
  `GenServer` module for data lineage.
  """
  use GenServer

  alias Graph.Drawing
  alias Graph.Layout
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
  def lineage(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:lineage, external_ids, opts}, 60_000)
  end

  @doc """
  Returns a lineage graph drawing for the specified `external_id`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def lineage(external_id, opts), do: lineage([external_id], opts)

  @doc """
  Returns an impact graph drawing for the specified `external_ids`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def impact(external_ids, opts) when is_list(external_ids) do
    GenServer.call(__MODULE__, {:impact, external_ids, opts}, 60_000)
  end

  @doc """
  Returns an impact graph drawing for the specified `external_id`. Branches can
  be pruned from the graph by specifying the `:excludes` option with a list of
  external_ids.
  """
  def impact(external_id, opts), do: impact([external_id], opts)

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
  def handle_call(:sample, _from, state) do
    case GraphData.sample(16) do
      %{type: type, g: g} = r ->
        source_ids = Graph.source_vertices(g)

        drawing =
          r
          |> Map.put(:source_ids, source_ids)
          |> Map.put(:hash, "#{:random.uniform(1_000_000)}")
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
end
