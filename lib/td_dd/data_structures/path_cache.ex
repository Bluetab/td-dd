defmodule TdDd.DataStructures.PathCache do
  @moduledoc """
  GenServer to cache structure paths (used to improve indexing performance).
  """
  use GenServer

  import Ecto.Query

  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  require Logger

  ## Client API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def path(id) do
    GenServer.call(__MODULE__, id, 10_000)
  end

  def refresh(timeout \\ 20_000) do
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
    state = do_load()
    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, _state) do
    state = do_load()
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(id, _from, state) do
    path = Map.get(state, id, [])
    {:reply, path, state}
  end

  ## Private functions

  defp do_load do
    Timer.time(
      fn -> load_cache() end,
      fn ms, _ -> Logger.info("Path cache refreshed in #{ms}ms") end
    )
  end

  defp load_cache do
    {:ok, graph} =
      Repo.transaction(fn ->
        graph =
          from(ds in DataStructureVersion,
            where: is_nil(ds.deleted_at),
            select: {ds.id, ds.name}
          )
          |> Repo.stream(max_rows: 1_000)
          |> Enum.reduce(Graph.new(), fn {id, name}, graph ->
            Graph.add_vertex(graph, id, name: name)
          end)

        from(dsr in DataStructureRelation,
          join: child in assoc(dsr, :child),
          join: parent in assoc(dsr, :parent),
          where: is_nil(child.deleted_at),
          where: is_nil(parent.deleted_at),
          select: {dsr.parent_id, dsr.child_id}
        )
        |> Repo.stream(max_rows: 1_000)
        |> Enum.reduce(graph, fn {parent_id, child_id}, graph ->
          Graph.add_edge(graph, parent_id, child_id)
        end)
      end)

    graph
    |> Graph.vertices()
    |> Enum.map(fn id -> {id, path(graph, id, [])} end)
    |> Map.new()
  end

  defp path(graph, id, acc) do
    case Graph.in_neighbours(graph, id) do
      [] -> Enum.map(acc, &Graph.vertex(graph, &1, :name))
      [h | _] -> path(graph, h, [h | acc])
    end
  end
end
