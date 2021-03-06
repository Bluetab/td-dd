defmodule TdDd.Lineage.Import do
  @moduledoc """
  GenServer module to manage importing graph data from CSV files.
  """

  use GenServer

  alias TdDd.Lineage.Import.Loader

  require Logger

  ## Client API

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def load(unit, nodes_path, rels_path, opts \\ []) do
    GenServer.cast(__MODULE__, {:load, unit, nodes_path, rels_path, opts})
  end

  def busy? do
    GenServer.call(__MODULE__, :busy?)
  end

  ## GenServer callbacks

  @impl true
  def init(_init_arg) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    {:ok, %{}}
  end

  @impl true
  def handle_call(:busy?, _from, state) do
    {:reply, map_size(state) > 0, state}
  end

  @impl true
  def handle_cast({:load, unit, nodes_path, rels_path, opts}, state) do
    Logger.info("Load started for unit #{unit.name}")

    %{ref: ref} =
      Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn ->
        Loader.load(unit, nodes_path, rels_path, Keyword.take(opts, [:timeout]))
      end)

    {:noreply, Map.put(state, ref, unit.name)}
  end

  @impl true
  def handle_info({_ref, _result}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, :normal}, state) do
    Logger.debug("#{inspect(ref)} completed")
    {:noreply, Map.delete(state, ref)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _error}, state) do
    {unit_name, state} = Map.pop(state, ref)
    Logger.warn("Load failed for unit=#{unit_name}")
    {:noreply, state}
  end
end
