defmodule TdDd.DataStructures.PathCache do
  @moduledoc """
  GenServer to cache structure paths (used to improve indexing performance).
  """
  use GenServer

  import Ecto.Query

  alias TdDd.Repo
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.DataStructureRelation

  require Logger

  ## Client API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def path(id) do
    GenServer.call(__MODULE__, id)
  end

  def refresh(timeout \\ 5000) do
    GenServer.call(__MODULE__, :refresh, timeout)
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :load_cache, 0)
    end

    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, state}
  end

  @impl true
  def handle_info(:load_cache, _state) do
    {ms, graph} = Timer.time(fn -> load_cache() end)
    Logger.info("Path cache loaded in #{ms}ms")
    {:noreply, graph}
  end

  @impl true
  def handle_call(:refresh, _from, _state) do
    {ms, graph} = Timer.time(fn -> load_cache() end)
    Logger.info("Path cache refreshed in #{ms}ms")
    {:reply, :ok, graph}
  end

  @impl true
  def handle_call(id, _from, state) do
    path = Map.get(state, id, [])
    {:reply, path, state}
  end

  defp load_cache do
    graph = :digraph.new()

    try do
      Repo.transaction(fn ->
        from(ds in DataStructureVersion,
          where: is_nil(ds.deleted_at),
          select: {ds.id, ds.name}
        )
        |> Repo.stream()
        |> Stream.each(fn {id, name} -> :digraph.add_vertex(graph, id, name) end)
        |> Stream.run()

        from(dsr in DataStructureRelation,
          join: child in assoc(dsr, :child),
          join: parent in assoc(dsr, :parent),
          where: is_nil(child.deleted_at),
          where: is_nil(parent.deleted_at),
          select: {dsr.parent_id, dsr.child_id}
        )
        |> Repo.stream()
        |> Stream.each(fn {parent_id, child_id} ->
          :digraph.add_edge(graph, parent_id, child_id)
        end)
        |> Stream.run()
      end)

      graph
      |> :digraph.vertices()
      |> Enum.map(fn id -> {id, path(graph, id, [])} end)
      |> Map.new()
    after
      :digraph.delete(graph)
    end
  end

  defp path(graph, id, acc) do
    case :digraph.in_neighbours(graph, id) do
      [] ->
        acc
        |> Enum.map(&:digraph.vertex(graph, &1))
        |> Enum.map(fn {_, name} -> name end)

      [h | _] ->
        path(graph, h, [h | acc])
    end
  end
end
