defmodule TdDd.Cache.StructureTypeLoader do
  @moduledoc """
  Module to manage cache loading of structure type information.
  """

  use GenServer

  alias TdCache.StructureTypeCache
  alias TdDd.DataStructures.DataStructuresTypes

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :load_structure_types, 0)
    end
    {:ok, state}
  end

  @impl true
  def handle_info(:load_structure_types, state) do
    load_structure_types()

    {:noreply, state}
  end

  ## Private functions

  defp load_structure_types do
    DataStructuresTypes.list_data_structure_types()
    |> load_structure_type_data()
  end

  def load_structure_type_data(structure_types) do
    results =
      structure_types
      |> Enum.map(&Map.take(&1, [:id, :structure_type, :template_id, :translation]))
      |> Enum.map(&StructureTypeCache.put/1)
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading failed")
    else
      Logger.info("Cached #{length(results)} structure types")
    end
  end
end
