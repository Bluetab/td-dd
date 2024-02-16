defmodule TdDd.Lineage.Import do
  @moduledoc """
  GenServer module to manage importing graph data from CSV files.
  """

  use GenServer

  alias TdDd.Lineage.Import.Loader
  alias TdDd.Lineage.Units

  require Logger

  ## Client API

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @spec load(binary(), binary(), map(), Keyword.t()) :: :ok
  def load(nodes_path, rels_path, %{"name" => _} = params, opts \\ []) do
    GenServer.cast(__MODULE__, {:load, nodes_path, rels_path, params, opts})
  end

  @spec busy? :: boolean()
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
  def handle_cast({:load, nodes_path, rels_path, %{"name" => name} = params, opts}, state) do
    %{ref: ref} =
      Task.Supervisor.async_nolink(TdDd.TaskSupervisor, fn ->
        do_load(nodes_path, rels_path, params, opts)
      end)

    {:noreply, Map.put(state, ref, name)}
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
    {:ok, unit} = Units.get_by(name: unit_name)
    Units.insert_event(unit, "LoadFailed")
    {:noreply, state}
  end

  defp do_load(nodes_path, rels_path, %{"name" => name} = params, opts) do
    Logger.info("Load started for unit #{name}")

    case Units.replace_unit(params) do
      {:ok, %{create: %Units.Unit{} = unit}} ->
        Loader.load(unit, nodes_path, rels_path, Keyword.take(opts, [:timeout]))

      {:error, failed_operation, _failed_value, _changes} = error ->
        Logger.warn("Failed loading unit #{name} - operation #{failed_operation}")
        error
    end
  end
end
